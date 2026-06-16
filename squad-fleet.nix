# squad-fleet.nix — YOUR fleet definition. This is the file you edit.
# ════════════════════════════════════════════════════════════════════════════
# This is the ONLY file most people need to touch. It declares your servers as
# data; the engine modules (squad-servers.nix, squadjs.nix) turn that data into
# systemd services, config files, firewall rules, mod downloads, and admin bots.
#
# Import it from your host configuration.nix:
#   imports = [ ./hardware-configuration.nix ./squad-fleet.nix ];
#
# ──────────────────────────────────────────────────────────────────────────
# ⚠️  SECRETS: every "CHANGE_ME_*" below is a placeholder. Replace them, and for
#     a real deployment move them out of git into sops-nix/agenix (see README).
#     Do NOT commit a real RCON password or Discord bot token to a public repo.
# ──────────────────────────────────────────────────────────────────────────
#
# Each instance needs UNIQUE ports (the engine asserts this and fails the build
# if any collide). Convention here: step every port by +10 per instance.
#
#   gamePort   (UDP)  default 7787, 7797, ...   the port players connect through
#   queryPort  (UDP)  default 27165, 27175, ... the port the browser reads
#   rconPort   (TCP)  default 21114, 21124, ...
#   beaconPort (UDP)  default 15000, 15010, ...

{ config, pkgs, lib, ... }:

let
  # Mod profiles — each is just an attrset of { workshopIds, layers, ... }.
  # Compose them per-instance with the `//` operator (attrset merge).
  mods = import ./mods;

  sd  = mods.steel-division;
  sm  = mods.supermod;
  icm = mods.icm;
  wz  = mods.warzone;
  ch  = mods.chornivsk;
  ml  = mods.modloader;
  dw  = mods.dynamic-weather;
  ac  = mods.armored-conflict;
  sat = mods.sat;
  ht  = mods.heli-training;

  # ── Secrets (placeholders — replace, then move to sops-nix/agenix) ──────────
  rconPassword   = "CHANGE_ME_RCON_PASSWORD";
  discordToken   = "CHANGE_ME_DISCORD_BOT_TOKEN";
  discordAdminCh = "CHANGE_ME_DISCORD_ADMIN_CHANNEL_ID";
  ownerSteamId   = "CHANGE_ME_YOUR_STEAMID64";   # e.g. 7656119xxxxxxxxxx
  discordInvite  = "discord.gg/CHANGE_ME";

  # ── A reusable "night vote pool" example ────────────────────────────────────
  # The end-of-round vote CARDS can ONLY offer layers in this list, so this is
  # how you constrain voting to (here) night layers only. Build pools like this
  # from a mod's layer set plus any extras you want votable.
  nightVotePool = sm.darkLayers ++ [
    "SU_GoingDark_Chornivsk_RAAS_v1"
    "SU_GoingDark_Chornivsk_RVAAS_v1"
    "SU_GoingDark_Chornivsk_Invasion_v1"
    "SU_GoingDark_Chornivsk_AAS_v1"
    "SU_GoingDark_Chornivsk_Seed_v1"
  ];
in
{
  imports = [ ./squad-servers.nix ./squadjs.nix ];

  hardware.graphics.enable32Bit = true;   # SteamCMD/_steam-run needs 32-bit libs

  # ════════════════════════════════════════════════════════════════════════
  #  THE GAME SERVERS
  # ════════════════════════════════════════════════════════════════════════
  services.squad-servers = {
    enable = true;
    user  = "squadsrv";
    group = "squadsrv";

    # Admins shared by every server in the fleet (per-instance admins also exist).
    sharedAdmins = [
      { steamId = ownerSteamId; group = "SuperAdmin"; comment = "owner"; }
    ];

    instances = {

      # ──────────────────────────────────────────────────────────────────────
      # EXAMPLE 1 — VANILLA + light mods (ENABLED).
      # A no-custom-layers server: ModLoader + Dynamic Weather inject effects
      # onto stock layers. Runs on any game version, so it's a great "always-up"
      # baseline and a safe first deploy to confirm the stack works end to end.
      # ──────────────────────────────────────────────────────────────────────
      vanilla = {
        enable = true;
        serverName = "[EXAMPLE] Vanilla + Dynamic Weather | ${discordInvite}";
        mods = ml.workshopIds // dw.workshopIds;   # ModLoader + Dynamic Weather
        modLoaderMods = [ dw.modLoaderPath ];       # ModLoader injects the weather actor
        layerRotation = [
          "Sumari_Seed_v1"                          # seed layer first (small, 1-flag)
          "Narva_RAAS_v1"
          "Yehorivka_RAAS_v1"
          "GooseBay_RAAS_v1"
          "Mutaha_RAAS_v1"
          "Tallil_RAAS_v1"
          "Fallujah_RAAS_v1"
          "Chora_RAAS_v1"
        ];
        mapRotationMode = "LayerList";              # plain rotation (no vote)
        gamePort = 7787;  queryPort = 27165;
        rconPort = 21114; beaconPort = 15000;
        rconPassword = rconPassword;
        motd = ''
          Welcome — example vanilla server.
          <a>This text is yellow (Squad supports only the &lt;a&gt; tag).</a>
          <a href="https://${lib.removePrefix "https://" discordInvite}">${discordInvite}</a>
        '';
        tags = [ "language_en" "mode_raas" "playstyle_focused" "exp_experience" "maprot_rotation" ];
        rules = [ "rule_play_objective" "rule_no_soloing_vehicle" ];
      };

      # ──────────────────────────────────────────────────────────────────────
      # EXAMPLE 2 — MODDED NIGHT-OPS with end-of-round VOTING + SAT (PARKED).
      # The flagship pattern: a full modded stack (Steel Division + SuperMod +
      # ModLoader + Dynamic Weather + Chornivsk + SAT), native vote CARDS
      # restricted to a night-only pool, and SAT for admin tools + cross-team
      # voice + parachutes + shovels-for-all. Flip enable=true (here AND its
      # squadjs entry below) to run it.
      #
      # WHY THE BOOT ORDER MATTERS:
      #   1. "VoiceConnect_Init"  — SAT's init layer; activates SAT then auto-skips
      #   2. "Chora_RAAS_v1"      — a vanilla layer is a GUARANTEED-bootable first
      #                             map; modded layer names can fail to load and a
      #                             bad first layer makes the server unjoinable.
      #   …then your modded night layers.
      # ──────────────────────────────────────────────────────────────────────
      night-ops = {
        enable = false;   # parked example — flip to true to run
        serverName = "[EXAMPLE] Night Ops ▌SuperMod ▌SD ▌${discordInvite}";
        mods = sd.workshopIds // sm.workshopIds
            // ml.workshopIds // dw.workshopIds // ch.workshopIds
            // sat.workshopIds;
        modLoaderMods = [ dw.modLoaderPath ];
        layerRotation = [
          "VoiceConnect_Init"                       # SAT init — activates SAT, auto-skips
          "Chora_RAAS_v1"                           # vanilla — guaranteed bootable
          "SU_GoingDark_Chornivsk_Seed_v1"
        ] ++ sm.darkLayers;

        # Native end-of-round vote CARDS. The vote draws from voteLayers below
        # (NOT from layerRotation), so it only ever offers night layers.
        mapRotationMode = "LayerList_Vote";
        voteLayers = nightVotePool;
        # VoteConfig.cfg — these are the REAL stock key names. (Common mistake:
        # "LayerCountPerVote"/"LayerVote_Duration" are from an old version and are
        # silently ignored. The correct keys are below.)
        voteConfig = {
          LayerOptionsNumber      = "6";   # how many MAP cards (2-6)
          TeamVoteOptionsNumber   = "6";   # how many FACTION choices per team (2-6)
          LayerVoteDuration       = "30";
          TeamVote_Duration       = "30";
          LowPlayerCountThreshold = "30";  # below this, uses LayerVotingLowPlayers.cfg
          UniqueMap               = "true";
          AutoSelectFactions      = "false";
          DisplayVotes            = "true";
          FirstLayer              = "Chora_RAAS_v1";  # boot layer each server start
        };

        gamePort = 7797;  queryPort = 27175;
        rconPort = 21124; beaconPort = 15010;
        rconPassword = rconPassword;
        motd = ''
          Night Ops — modded NVG night layers. Example server.
          <a href="https://${lib.removePrefix "https://" discordInvite}">${discordInvite}</a>
        '';
        tags  = [ "language_en" "mode_raas" "mode_invasion" "playstyle_milsim" "exp_experience" "maprot_rotation" ];
        rules = [ "rule_play_objective" "rule_no_soloing_vehicle" "rule_vehicle_name_claim" ];

        # SAT (Squad Admin Tools). Settings are SEEDED ONCE into
        # SquadAdminTools.cfg, then SAT owns the file (it regenerates it on
        # updates and you can tune it in-game). nixos-rebuild will NOT overwrite
        # it after first seed — see `satConfig` docs in squad-servers.nix.
        # `sat.compatibleConfig` = the NVG/SuperMod/SD-safe preset (voice +
        # parachutes + engineer shovels ON; lighting/weapons/anti-cheat OFF).
        # VotingVoice=true adds cross-team voice DURING the vote.
        satConfig = sat.compatibleConfig // { VotingVoice = "true"; };
      };

      # ──────────────────────────────────────────────────────────────────────
      # EXAMPLE 3 — a single-mod server (PARKED). Shows the minimal shape:
      # one mod, a rotation, ports. Armored Conflict = tank-on-tank game mode.
      # ──────────────────────────────────────────────────────────────────────
      armored = {
        enable = false;
        serverName = "[EXAMPLE] Armored Conflict | ${discordInvite}";
        mods = ac.workshopIds;
        layerRotation = ac.defaultRotation;
        mapRotationMode = "LayerList";
        gamePort = 7807;  queryPort = 27185;
        rconPort = 21134; beaconPort = 15020;
        rconPassword = rconPassword;
        motd = "Armored Conflict — tank-on-tank. ${discordInvite}";
        tags = [ "language_en" "mode_raas" "playstyle_focused" "exp_experience" "maprot_rotation" ];
      };

      # ──────────────────────────────────────────────────────────────────────
      # EXAMPLE 4 — a training/sandbox server (PARKED). Heli Landing Training.
      # ──────────────────────────────────────────────────────────────────────
      heli-training = {
        enable = false;
        serverName = "[EXAMPLE] Heli Landing Training | ${discordInvite}";
        mods = ht.workshopIds;
        layerRotation = ht.defaultRotation;
        mapRotationMode = "LayerList";
        gamePort = 7817;  queryPort = 27195;
        rconPort = 21144; beaconPort = 15030;
        rconPassword = rconPassword;
        motd = "Helicopter Landing Training — spawn a heli with F9. ${discordInvite}";
        tags = [ "language_en" "mode_training" "playstyle_focused" "exp_experience" "maprot_rotation" ];
      };

    };

    autoUpdate = true;         # one nightly cycle updates the shared install +
    autoUpdateTime = "05:30";  # all workshop mods, then restarts every instance
  };

  # ════════════════════════════════════════════════════════════════════════
  #  SQUADJS — admin framework / Discord bots / broadcasts (one per server)
  # ════════════════════════════════════════════════════════════════════════
  # Each entry pairs with a game instance above (matching ports). The Discord
  # bot token + admin channel are shared (one bot drives all instances). Parked
  # game servers MUST have their squadjs parked too (enable=false) or SquadJS
  # will crash-loop trying to reach an RCON port that isn't listening.
  services.squadjs = {
    enable = true;
    gameGroup = "squadsrv";

    instances = let
      mk = { svc, q, r, welcome }: {
        gameService = svc;
        queryPort = q;
        rconPort = r;
        rconPassword = rconPassword;
        logDir     = "/var/lib/squad/instances/${lib.removePrefix "squad-" svc}/persist/Saved/Logs";
        adminsFile = "/var/lib/squad/instances/${lib.removePrefix "squad-" svc}/farm/SquadGame/ServerConfig/Admins.cfg";
        welcomeMessage = welcome;
        broadcasts = [
          "Join our community Discord: ${discordInvite}"
          "Vote for the next layer at end of round."
        ];
        discord = {
          token = discordToken;
          adminChannelId = discordAdminCh;
          chatChannelId = null;
          rconChannelId = null;
          killfeedChannelId = null;
        };
      };
    in {
      # ENABLED — matches the enabled `vanilla` game instance
      vanilla       = mk { svc = "squad-vanilla";       q = 27165; r = 21114;
        welcome = "Welcome! Example vanilla server. ${discordInvite}"; };

      # PARKED — match their parked game instances (enable=false)
      night-ops     = mk { svc = "squad-night-ops";     q = 27175; r = 21124;
        welcome = "Welcome to Night Ops! ${discordInvite}"; }
        // { enable = false; };
      armored       = mk { svc = "squad-armored";       q = 27185; r = 21134;
        welcome = "Welcome to Armored Conflict! ${discordInvite}"; }
        // { enable = false; };
      heli-training = mk { svc = "squad-heli-training"; q = 27195; r = 21144;
        welcome = "Welcome to Heli Training! ${discordInvite}"; }
        // { enable = false; };
    };
  };

  environment.systemPackages = with pkgs; [ htop tmux ];
  zramSwap.enable = true;
}
