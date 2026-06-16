# squad-servers.nix
#
# Multi-instance NixOS module for modded Squad dedicated servers.
#
# Architecture:
#
#   /var/lib/squad/shared/server/            ONE base-game install (≈30 GB)
#   /var/lib/squad/shared/server/steamapps/
#     workshop/content/393380/<id>/          ONE copy of every mod, shared
#
#   /var/lib/squad/instances/<name>/farm/    per-server symlink farm of the
#                                            shared install, with its OWN
#                                            ServerConfig, Saved/ and
#                                            Plugins/Mods (only that
#                                            instance's mods linked in)
#   /var/lib/squad/instances/<name>/persist/ Saved/, Bans.cfg — survives
#                                            rebuilds
#
# So N servers cost: 1× game + 1× each unique mod + a few MB per instance.
# Each instance is its own systemd unit: squad-<name>.service.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.squad-servers;

  steamAppId    = "403240";
  workshopAppId = "393380";

  sharedServer   = "${cfg.stateDir}/shared/server";
  sharedWorkshop = "${sharedServer}/steamapps/workshop/content/${workshopAppId}";

  instanceDir = name: "${cfg.stateDir}/instances/${name}";

  # Union of every mod ID used by any instance — downloaded once.
  allModIds = unique (concatMap (i: attrValues i.mods) (attrValues cfg.instances));

  enabledInstances = filterAttrs (_: i: i.enable) cfg.instances;

  # ----- per-instance generated configs -----------------------------------

  serverCfg = name: i: pkgs.writeText "Server-${name}.cfg" ''
    ServerName="${i.serverName}"
    MaxPlayers=${toString i.maxPlayers}
    NumReservedSlots=${toString i.reservedSlots}
    ShouldAdvertise=${if i.advertise then "true" else "false"}
    IsLANMatch=${if i.lanMatch then "true" else "false"}
    PublicQueueLimit=${toString i.publicQueueLimit}
    Password="${i.serverPassword}"
    ${optionalString (i.mapRotationMode != null) "MapRotationMode=${i.mapRotationMode}"}
    RandomizeAtStart=false
    ${optionalString (i.tags != []) "Tags=${concatStringsSep " " i.tags}"}
    ${optionalString (i.rules != []) "Rules=${concatStringsSep " " i.rules}"}
    ${i.extraServerCfg}
  '';

  rconCfg = name: i: pkgs.writeText "Rcon-${name}.cfg" ''
    Port=${toString i.rconPort}
    Password=${i.rconPassword}
  '';

  adminsCfg = name: i: pkgs.writeText "Admins-${name}.cfg" ''
    Group=SuperAdmin:startvote,changemap,pause,cheat,private,balance,chat,kick,ban,config,cameraman,immune,manageserver,featuretest,reserve,demos,debug,teamchange,forceteamchange,canseeadminchat
    Group=Admin:changemap,balance,chat,kick,ban,cameraman,immune,reserve,teamchange,forceteamchange,canseeadminchat
    Group=Moderator:chat,kick,cameraman,canseeadminchat
    Group=Whitelist:reserve

    ${concatMapStringsSep "\n"
      (a: "Admin=${a.steamId}:${a.group} // ${a.comment}")
      i.admins}
  '';

  motdCfg = name: i: pkgs.writeText "MOTD-${name}.cfg" i.motd;

  # SquadAdminTools.cfg — emits `key = value` lines from i.satConfig (an attrset).
  # Only used to SEED the file once (Option B); SAT owns it thereafter.
  satCfgFile = name: i: pkgs.writeText "SquadAdminTools-${name}.cfg"
    ((concatStringsSep "\n" (mapAttrsToList (k: v: "${k} = ${v}") i.satConfig)) + "\n");

  layersCfg = name: i: pkgs.writeText "Layers-${name}.cfg"
    (concatStringsSep "\n" i.layerRotation + "\n");

  # LayerVoting.cfg — the pool the end-of-round vote CARDS draw from. The vote
  # can ONLY ever offer layers listed here, so restrict to taste (e.g. night).
  voteLayersCfg = name: i: pkgs.writeText "LayerVoting-${name}.cfg"
    (concatStringsSep "\n" i.voteLayers + "\n");

  # VoteConfig.cfg — vote behaviour (cards shown, durations, first layer).
  voteConfigCfg = name: i: pkgs.writeText "VoteConfig-${name}.cfg"
    (concatStringsSep "\n" (mapAttrsToList (k: v: "${k}=${v}") i.voteConfig) + "\n");

  # ----- scripts -----------------------------------------------------------

  # ONE download for everything: base server + union of all workshop mods.
  # SteamCMD has an internal timeout that large (multi-GB) workshop items
  # routinely exceed; downloads RESUME on retry, so each item is attempted
  # in its own steamcmd session with up to $MAX_TRIES retries.
  downloadScript = pkgs.writeShellScript "squad-download" ''
    set -euo pipefail
    export HOME=${cfg.stateDir}
    mkdir -p ${sharedServer}
    MAX_TRIES=15

    steam() {
      ${pkgs.steamcmd}/bin/steamcmd \
        +force_install_dir ${sharedServer} \
        +login anonymous "$@" +quit
    }

    # --- base game: app_update also resumes, retry until success ----------
    try=1
    until out=$(steam +app_update ${steamAppId} validate 2>&1) \
          && echo "$out" | grep -q "Success! App '${steamAppId}'"; do
      echo "$out" | tail -5
      if [ "$try" -ge "$MAX_TRIES" ]; then
        echo "FATAL: app_update failed after $MAX_TRIES attempts" >&2
        exit 1
      fi
      try=$((try + 1))
      echo "app_update incomplete — retrying ($try/$MAX_TRIES)..."
      sleep 5
    done
    echo "Base server installed/updated."
    chmod +x ${sharedServer}/SquadGameServer.sh || true

    # --- workshop mods: one session per item, resume-and-retry ------------
    fail=0
    for id in ${concatStringsSep " " allModIds}; do
      ok=0
      for try in $(seq 1 "$MAX_TRIES"); do
        echo "Workshop item $id — attempt $try/$MAX_TRIES"
        out=$(steam +workshop_download_item ${workshopAppId} "$id" validate 2>&1) || true
        if echo "$out" | grep -q "Success. Downloaded item $id"; then
          echo "Workshop item $id done."
          ok=1
          break
        fi
        echo "$out" | grep -iE "error|timeout" | tail -3 || true
        sleep 5
      done
      if [ "$ok" = 0 ]; then
        echo "ERROR: workshop item $id failed after $MAX_TRIES attempts" >&2
        fail=1
      fi
    done
    [ "$fail" = 0 ] || exit 1
  '';

  # Build one instance's disposable symlink farm from the shared install.
  prepareScript = name: i: pkgs.writeShellScript "squad-prepare-${name}" ''
    set -euo pipefail
    INST=${instanceDir name}
    FARM="$INST/farm"
    PERSIST="$INST/persist"

    mkdir -p "$PERSIST/Saved"
    touch "$PERSIST/Bans.cfg"

    # Rebuild the farm from scratch — it's all symlinks, nothing of value
    rm -rf "$FARM"
    mkdir -p "$FARM"
    cp -as ${sharedServer}/. "$FARM"/

    # CRITICAL: Unreal resolves its project directory from the BINARY's
    # real path (/proc/self/exe). If the executable is a symlink into
    # shared/, the engine treats shared/ as home and ignores this farm's
    # ServerConfig entirely (no RCON, default map, no advertising!).
    # Materialize the launcher + everything in Binaries/Linux as real
    # files (hardlinks: zero extra disk, same filesystem; cp as fallback).
    rm -f "$FARM/SquadGameServer.sh"
    cp ${sharedServer}/SquadGameServer.sh "$FARM/SquadGameServer.sh"
    chmod +x "$FARM/SquadGameServer.sh"
    BINDIR="$FARM/SquadGame/Binaries/Linux"
    for f in "$BINDIR"/*; do
      if [ -L "$f" ]; then
        tgt=$(readlink -f "$f")
        rm "$f"
        ln "$tgt" "$f" 2>/dev/null || cp -a "$tgt" "$f"
      fi
    done
    chmod +x "$BINDIR/SquadGameServer" 2>/dev/null || true

    # Detach the bits that must be instance-private
    rm -rf "$FARM/SquadGame/Saved" \
           "$FARM/SquadGame/ServerConfig" \
           "$FARM/SquadGame/Plugins/Mods" \
           "$FARM/steamapps" 2>/dev/null || true
    mkdir -p "$FARM/SquadGame/Plugins/Mods" "$FARM/SquadGame/ServerConfig"
    ln -sfn "$PERSIST/Saved" "$FARM/SquadGame/Saved"

    # Only THIS instance's mods get linked in
    ${concatMapStringsSep "\n"
      (id: ''ln -sfn ${sharedWorkshop}/${id} "$FARM/SquadGame/Plugins/Mods/${id}"'')
      (attrValues i.mods)}

    # Declarative configs; Bans.cfg stays persistent + mutable
    install -m 0644 ${serverCfg name i}  "$FARM/SquadGame/ServerConfig/Server.cfg"
    install -m 0600 ${rconCfg name i}    "$FARM/SquadGame/ServerConfig/Rcon.cfg"
    install -m 0644 ${adminsCfg name i}  "$FARM/SquadGame/ServerConfig/Admins.cfg"
    install -m 0644 ${motdCfg name i}    "$FARM/SquadGame/ServerConfig/Motd.cfg"
    install -m 0644 ${motdCfg name i}    "$FARM/SquadGame/ServerConfig/MOTD.cfg"
    install -m 0644 ${layersCfg name i}  "$FARM/SquadGame/ServerConfig/LayerRotation.cfg"
    install -m 0644 ${layersCfg name i}  "$FARM/SquadGame/ServerConfig/LevelRotation.cfg"
    ${optionalString (i.voteLayers != [ ]) ''
    # end-of-round vote-card pool + behaviour (MapRotationMode must be LayerList_Vote)
    install -m 0644 ${voteLayersCfg name i} "$FARM/SquadGame/ServerConfig/LayerVoting.cfg"
    install -m 0644 ${voteConfigCfg name i} "$FARM/SquadGame/ServerConfig/VoteConfig.cfg"
    ''}
    ln -sfn "$PERSIST/Bans.cfg" "$FARM/SquadGame/ServerConfig/Bans.cfg"

    ${optionalString (i.modLoaderMods != [ ]) ''
    # ModLoader config — lives under Saved/, which we persist
    mkdir -p "$PERSIST/Saved/ModLoader"
    install -m 0644 ${pkgs.writeText "ModLoader-${name}.json" (builtins.toJSON {
      Version = 2;
      mods = i.modLoaderMods;
    })} "$PERSIST/Saved/ModLoader/ModLoader.json"
    ''}

    ${optionalString (i.satConfig != null) ''
    # Squad Admin Tools (SAT) config — OPTION B: SAT owns this file. We seed it
    # ONCE if absent, then never touch it again, so SAT (and in-game tuning /
    # SAT updates that regenerate it) keep ownership and nixos-rebuild won't
    # clobber it. Lives under Saved/, which we persist.
    mkdir -p "$PERSIST/Saved/SquadAdminTools"
    if [ ! -f "$PERSIST/Saved/SquadAdminTools/SquadAdminTools.cfg" ]; then
      install -m 0644 ${satCfgFile name i}         "$PERSIST/Saved/SquadAdminTools/SquadAdminTools.cfg"
      echo "SAT: seeded SquadAdminTools.cfg from declarative template (first run)"
    else
      echo "SAT: SquadAdminTools.cfg already exists — leaving SAT-owned (Option B)"
    fi
    ''}
  '';

  # ----- instance option type ----------------------------------------------

  instanceModule = types.submodule ({ name, ... }: {
    options = {
      enable = mkOption { type = types.bool; default = true; };

      serverName = mkOption {
        type = types.str;
        default = "NixOS Squad — ${name}";
      };

      mods = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = ''
          Workshop mods for THIS instance (name -> workshop ID).
          Compose from profiles: `mods = sd.workshopIds // icm.workshopIds;`
        '';
      };

      layerRotation = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Layer names; modded names via RCON `AdminListLayers`.";
      };

      modLoaderMods = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "/DynamicWeatherSystem/BP_Squad_UltraDynamicWeather_01_Random.BP_Squad_UltraDynamicWeather_01_Random_C" ];
        description = ''
          ModLoader actor paths written to
          SquadGame/Saved/ModLoader/ModLoader.json. Only takes effect when
          the ModLoader mod is in this instance's `mods`. Each addon's
          Workshop page documents its path string.
        '';
      };

      # Every instance MUST have unique ports.
      gamePort   = mkOption { type = types.port; description = "UDP; uses this and +1."; };
      queryPort  = mkOption { type = types.port; description = "UDP; uses this and +1."; };
      rconPort   = mkOption { type = types.port; };
      beaconPort = mkOption { type = types.port; };

      rconPassword     = mkOption { type = types.str; };
      serverPassword   = mkOption { type = types.str; default = ""; };
      lanMatch         = mkOption {
        type = types.bool;
        default = false;
        description = "LAN mode (IsLANMatch). Use for same-network testing — NAT loopback is otherwise required to host and play on the same network. LAN servers are not advertised publicly.";
      };
      maxPlayers       = mkOption { type = types.ints.between 2 100; default = 100; };
      reservedSlots    = mkOption { type = types.int; default = 0; };
      publicQueueLimit = mkOption { type = types.int; default = 25; };
      advertise        = mkOption { type = types.bool; default = true; };
    multihome = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "203.0.113.10";
      description = "Bind to a specific IP on multi-IP machines (MULTIHOME launch arg).";
    };

    cpuAffinity = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "2,3";
      description = "Pin this instance to specific CPU cores (systemd CPUAffinity).";
    };

    mapRotationMode = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "LayerList_Vote";
      description = ''
        Squad's MapRotationMode. Set to "LayerList_Vote" to enable the
        NATIVE end-of-round voting screen (layer + faction/unit cards,
        v7.2+). Vote pool comes from the layer rotation. When enabled,
        disable SquadJS MapVote on the same instance to avoid two voting
        systems fighting over the next layer. null = engine default
        (fixed rotation).
      '';
    };
      motd             = mkOption { type = types.lines; default = "Welcome!"; };

      satConfig = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        example = {
          OverrideGamemodeState = "limited";
          CrossTeamVoiceEnabled = "true";
          SATParachutes = "true";
          ShovelsForAll = "engineer";
        };
        description = ''
          Squad Admin Tools (SAT) settings, emitted as `key = value` lines into
          SquadAdminTools.cfg. OPTION B: this file is SEEDED ONCE if absent, then
          left for SAT to own (in-game tuning + SAT's own regeneration on updates
          persist; nixos-rebuild won't overwrite it). To re-seed from this
          template, delete the live file and redeploy. Requires the SAT mod
          (workshop 3193475024) in `mods` and booting a SAT init layer
          (VoiceConnect_Init or SAT_Gorodok_*/SAT_Tallil_*) for SAT to activate.
        '';
      };

      voteLayers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "SU_GoingDark_Yehorivka_RAAS_v1" "SU_GoingDark_Tallil_RAAS_v1" ];
        description = ''
          Layer pool for the end-of-round VOTE CARDS (written to LayerVoting.cfg).
          The vote can only ever offer layers from this list — restrict it to
          exactly the layers you want votable (e.g. night layers only). Requires
          mapRotationMode = "LayerList_Vote". Empty = no voting files written.
        '';
      };

      voteConfig = mkOption {
        type = types.attrsOf types.str;
        default = {
          LayerOptionsNumber = "6";             # map/layer cards (2-6)
          TeamVoteOptionsNumber = "6";          # faction choices per team (2-6)
          LayerVoteDuration = "30";
          TeamVote_Duration = "30";
          UniqueMap = "true";
          AutoSelectFactions = "false";
          DisplayVotes = "true";
        };
        description = ''
          VoteConfig.cfg settings (key=value). Controls vote-card behaviour:
          LayerOptionsNumber (map cards), TeamVoteOptionsNumber (faction choices),
          durations. Both option counts accept 2-6.
          Set FirstLayer here to control the boot layer; if unset, the first line
          of LayerVoting.cfg is used. Only written when voteLayers is non-empty.
        '';
      };
      tags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "language_en" "mode_raas" "mode_invasion" "playstyle_milsim" "maprot_voting" ];
        description = ''
          Server browser filter tags (space-joined into the Server.cfg `Tags=`
          line). Use the official tag codes. Category limits enforced by the
          game: Language max 2 (language_en, language_de, language_ru, ...),
          Game Mode max 3 (mode_raas, mode_invasion, mode_aas, mode_seed, ...),
          Playstyle max 1 (playstyle_milsim/_focused/_relaxed), Experience max 1
          (exp_newplayer/exp_experience), Map Rotation max 1
          (maprot_voting/maprot_rotation).
        '';
      };

      rules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "rule_play_objective" "rule_no_main_camping" "rule_no_soloing_vehicle" ];
        description = ''
          Server browser RULES tags (space-joined into the Server.cfg `Rules=`
          line). Use the official rule codes, e.g. rule_vehicle_name_claim,
          rule_play_objective, rule_no_main_camping, rule_no_soloing_vehicle,
          rule_mech_inf_restrictions, rule_lock_restrictions. Full list:
          https://squad.fandom.com/wiki/Server_Configuration#Tag_System
        '';
      };
      extraServerCfg   = mkOption { type = types.lines; default = ""; };

      admins = mkOption {
        default = [ ];
        type = types.listOf (types.submodule {
          options = {
            steamId = mkOption { type = types.str; };
            group   = mkOption {
              type = types.enum [ "SuperAdmin" "Admin" "Moderator" "Whitelist" ];
              default = "Admin";
            };
            comment = mkOption { type = types.str; default = ""; };
          };
        });
      };
    };
  });

in
{
  ###### Options ###########################################################

  options.services.squad-servers = {
    enable = mkEnableOption "modded Squad dedicated server fleet";

    stateDir = mkOption { type = types.path; default = "/var/lib/squad"; };
    user     = mkOption { type = types.str;  default = "squad"; };
    group    = mkOption { type = types.str;  default = "squad"; };

    instances = mkOption {
      type = types.attrsOf instanceModule;
      default = { };
      description = "Named server instances, each with its own mods/ports.";
    };

    sharedAdmins = mkOption {
      default = [ ];
      description = "Admins appended to every instance.";
      type = types.listOf (types.submodule {
        options = {
          steamId = mkOption { type = types.str; };
          group   = mkOption {
            type = types.enum [ "SuperAdmin" "Admin" "Moderator" "Whitelist" ];
            default = "Admin";
          };
          comment = mkOption { type = types.str; default = ""; };
        };
      });
    };

    autoUpdate     = mkOption { type = types.bool; default = true; };
    autoUpdateTime = mkOption { type = types.str;  default = "06:00"; };
    openFirewall   = mkOption { type = types.bool; default = true; };
    openEphemeralPorts = mkOption {
      type = types.bool;
      default = true;
      description = "Open UDP 30000+ (Squad uses ephemeral UDP ports for established client connections, per the official wiki).";
    };
  };

  ###### Implementation ####################################################

  config = mkIf cfg.enable {

    assertions =
      let
        ports = i: [ i.gamePort (i.gamePort + 1) i.queryPort (i.queryPort + 1)
                     i.rconPort i.beaconPort ];
        allPorts = concatMap ports (attrValues enabledInstances);
      in [
        {
          assertion = length allPorts == length (unique allPorts);
          message = "services.squad-servers: port collision between instances (remember each uses gamePort, gamePort+1, queryPort, queryPort+1).";
        }
        {
          assertion = enabledInstances != { };
          message = "services.squad-servers.enable is true but no instances are defined.";
        }
      ];

    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg)
        [ "steamcmd" "steam" "steam-run" "steam-unwrapped" "steam-original" ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.stateDir;
      createHome = true;
    };
    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = (mapAttrsToList (name: _:
      # prune UE log backups after 14 days (active log stays: fresh mtime)
      "e /var/lib/squad/instances/${name}/persist/Saved/Logs - - - 14d"
    ) enabledInstances) ++ [
      "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/instances 0750 ${cfg.user} ${cfg.group} -"
      # enforce the mode on EXISTING dirs too (d only applies on create), so
      # the squadjs group can always traverse to the logs it tails:
      "z ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} -"
      "z ${cfg.stateDir}/instances 0750 ${cfg.user} ${cfg.group} -"
    ];

    # ---- all units: shared downloader + per-instance prepare/run ----------
    systemd.services = mkMerge ([
      {
        squad-download = {
          description = "Download/update Squad server + all Workshop mods (shared)";
          # NOT wantedBy multi-user.target: per-instance prepare units pull
          # this in via `requires`, and keeping it out of the default boot
          # transaction means `nixos-rebuild switch` doesn't block for the
          # duration of a 30+ GB SteamCMD download.
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            ExecStart = downloadScript;
            TimeoutStartSec = "4h";
            PrivateTmp = true;
          };
        };
      }
    ] ++ flatten (mapAttrsToList (name: i: [
      {
        "squad-${name}-prepare" = {
          description = "Build symlink farm for Squad instance ${name}";
          after = [ "squad-download.service" ];
          requires = [ "squad-download.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            ExecStart = prepareScript name (i // {
              admins = i.admins ++ cfg.sharedAdmins;
            });
          };
        };

        "squad-${name}" = {
          description = "Squad dedicated server: ${name}";
          wantedBy = [ "multi-user.target" ];
          after    = [ "network-online.target" "squad-${name}-prepare.service" ];
          wants    = [ "network-online.target" ];
          requires = [ "squad-${name}-prepare.service" ];
          serviceConfig = {
            User = cfg.user;
            Group = cfg.group;
            # group-readable logs/saved so the squadjs user (same group) can
            # tail SquadGame.log — without this SquadJS dies with EACCES
            UMask = "0027";
            WorkingDirectory = "${instanceDir name}/farm";
            ExecStart = ''
              ${pkgs.steam-run}/bin/steam-run ${instanceDir name}/farm/SquadGameServer.sh \
                Port=${toString i.gamePort} \
                QueryPort=${toString i.queryPort} \
                RCONPORT=${toString i.rconPort} \
                beaconport=${toString i.beaconPort} \
                ${optionalString (i.multihome != null) "MULTIHOME=${i.multihome} \\"}
                FIXEDMAXPLAYERS=${toString i.maxPlayers} \
                FIXEDMAXTICKRATE=50 \
                RANDOM=NONE \
                -log \
                -LogCmds="LogSquad Verbose, LogSquadTrace Verbose, LogGameState Log, LogEOS Warning, LogRedpointEOS Warning, LogEOSHTTP Warning"
            '';
            # `unless-stopped` semantics: survive crashes AND clean exits
            # (modded UE servers occasionally exit 0 on internal errors)
            Restart = "always";
            RestartSec = "15s";
            # under memory pressure, kill the game first — never sshd
            OOMScoreAdjust = 300;
            # give UE time to flush Bans.cfg / Saved state on stop
            TimeoutStopSec = "120s";
            LimitNOFILE = 65536;
            ProtectSystem = "full";
            ReadWritePaths = [ cfg.stateDir ];
            PrivateTmp = true;
          } // optionalAttrs (i.cpuAffinity != null) {
            # community --cpuset-cpus equivalent: dedicate cores per instance
            CPUAffinity = i.cpuAffinity;
          };
        };
      }
    ]) enabledInstances) ++ [
      (mkIf cfg.autoUpdate {
        squad-fleet-update = {
          description = "Stop fleet, update shared install + mods, restart fleet";
          serviceConfig.Type = "oneshot";
          script =
            let units = mapAttrsToList (n: _: "squad-${n}.service") enabledInstances;
            in ''
              # safety net: persist configs + bans, 14-day retention
              BK=${cfg.stateDir}/backups
              mkdir -p "$BK"
              ${pkgs.gnutar}/bin/tar czf "$BK/persist-$(date +%F).tar.gz" \
                --exclude='*/Saved/Logs' \
                -C ${cfg.stateDir}/instances . 2>/dev/null || true
              ls -1t "$BK"/persist-*.tar.gz 2>/dev/null | tail -n +15 | ${pkgs.findutils}/bin/xargs -r rm --

              ${pkgs.systemd}/bin/systemctl stop ${concatStringsSep " " units}
              ${pkgs.systemd}/bin/systemctl restart squad-download.service
              ${pkgs.systemd}/bin/systemctl start ${concatStringsSep " " units}
            '';
        };
      })
    ]);

    systemd.timers.squad-fleet-update = mkIf cfg.autoUpdate {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.autoUpdateTime;
        Persistent = true;
      };
    };

    # ---- firewall: union of every instance's ports -------------------------
    # Port matrix per the official wiki (Server_Installation "Ports to Open"):
    #   game, game+1        = UDP
    #   query, query+1      = UDP and TCP
    #   beacon              = UDP and TCP  (in-game browser pings via beacon!)
    #   rcon                = UDP and TCP
    #   ephemeral 30000+    = UDP (client connections after initial connect)
    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = unique (concatMap
        (i: [ i.gamePort (i.gamePort + 1) i.queryPort (i.queryPort + 1)
              i.beaconPort i.rconPort ])
        (attrValues enabledInstances));
      allowedTCPPorts = unique (concatMap
        (i: [ i.queryPort (i.queryPort + 1) i.beaconPort i.rconPort ])
        (attrValues enabledInstances));
      allowedUDPPortRanges = mkIf cfg.openEphemeralPorts [
        { from = 30000; to = 65535; }
      ];
    };
  };
}
