# Declarative Modded Squad Server Fleet on NixOS

Run a fleet of modded **[Squad](https://joinsquad.com/)** dedicated servers from a
single, reproducible NixOS configuration. Define each server as data — mods,
layers, ports, voting, admin tools — and `nixos-rebuild` turns it into running
systemd services, generated config files, firewall rules, automatic Steam
Workshop mod downloads, and per-server [SquadJS](https://github.com/Team-Silver-Sphere/SquadJS)
admin bots.

> **What makes this different from a bash-script setup:** everything is
> declarative and composable. Adding a server is a few lines. Adding a mod is
> `someMod.workshopIds // anotherMod.workshopIds`. The whole fleet — six servers,
> their mods, their admin bots — rebuilds from one `git` repo, and a fresh box
> reaches an identical state with one command.

---

## Features

- **Multi-instance fleet** — many servers from one config, each with isolated
  state, its own ports, mods, and rotation. Port collisions fail the build, not
  production.
- **Composable mod profiles** — each mod is a small `{ workshopIds; layers; }`
  attrset in `mods/`. Mix them per server with `//`. Includes profiles for
  Steel Division, SuperMod, ICM, Warzone, Chornivsk, ModLoader, Dynamic Weather,
  Armored Conflict, Squad Admin Tools, Galactic Contention, and Heli Training.
- **Automatic Steam Workshop downloads** — the union of all enabled servers'
  mods is fetched via SteamCMD, with resume-on-retry for multi-GB items.
- **Native end-of-round map voting** — generates the `LayerVoting.cfg` /
  `VoteConfig.cfg` files for Squad's vote-card UI, with the vote pool
  constrained to whatever layers you choose (e.g. night-only).
- **Squad Admin Tools (SAT) integration** — cross-team voice, parachutes,
  shovels-for-all, and admin tooling, with its self-managed config seeded once
  then left under SAT's ownership (so in-game tuning and mod updates persist).
- **SquadJS per server** — Discord notifications, in-game broadcasts, welcome
  messages, auto-kick/seeding/teamkill plugins. One bot drives the whole fleet.
- **Server-browser correctness** — sets the official filter `tags` and `rules`
  codes, MOTD, and a binary-advertising fix so servers actually appear and are
  joinable (a subtle Unreal `ProjectDir` quirk — see notes below).
- **Provision from scratch or deploy to an existing host** — `flake.nix` +
  `disko.nix` support a `nixos-anywhere` bare-metal install, or just use
  `nixos-rebuild switch --target-host`.

---

## Repository layout

```
.
├── flake.nix                 # entry point; pins nixpkgs, wires disko + config
├── configuration.nix         # host config (boot, network, ssh) -> imports the fleet
├── disko.nix                 # example disk layout (for nixos-anywhere)
├── hardware-configuration.nix# PLACEHOLDER — generate yours on the box
│
├── squad-fleet.nix           # ★ YOU EDIT THIS — declares your servers as data
│
├── squad-servers.nix         # engine: game-server module (services.squad-servers)
├── squadjs.nix               # engine: SquadJS module (services.squadjs)
│
└── mods/
    ├── default.nix           # aggregates all profiles into one attrset
    ├── steel-division.nix     # each profile: { workshopIds; layers; ... }
    ├── supermod.nix
    ├── sat.nix                # also exposes a compatibleConfig preset
    └── …
```

The two `squad-*.nix` engine modules are generic — you shouldn't need to edit
them. **`squad-fleet.nix` is the file you live in.**

---

## Quick start

### 1. Prerequisites
- A NixOS host (bare metal or VPS) with flakes enabled, or a target box you'll
  provision with [`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere).
- A Steam account is **not** required — the server + mods download anonymously.

### 2. Clone and configure
```bash
git clone https://github.com/CHANGE_ME/squad-nixos-fleet.git
cd squad-nixos-fleet
```
Edit **`squad-fleet.nix`** and replace every `CHANGE_ME_*` placeholder:
- `rconPassword`, `discordToken`, `discordAdminCh`, `ownerSteamId`, `discordInvite`
- enable the servers you want (`enable = true;`) and set their `serverName`,
  `mods`, `layerRotation`, and ports.

Then set your SSH key + hostname in `configuration.nix`, and (if installing
fresh) your disk in `disko.nix`.

> **Secrets:** the placeholders keep things simple, but **don't commit real
> secrets to a public repo.** For production, store the RCON password and
> Discord token with [sops-nix](https://github.com/Mic92/sops-nix) or
> [agenix](https://github.com/ryantm/agenix) and reference them instead of
> inline strings. See *Secrets* below.

### 3. Build-test (always do this first)
```bash
git add -A                                   # flakes only see git-tracked files!
nixos-rebuild build --flake .#squad
```
A clean build means the whole fleet evaluates — ports don't collide, mod
profiles resolve, voting/SAT config is valid.

### 4. Deploy
**To an existing NixOS host:**
```bash
git commit -am "configure fleet"
nixos-rebuild switch --flake .#squad --target-host root@YOUR_SERVER_IP
```
**To a fresh box (provision from scratch):**
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#squad root@YOUR_SERVER_IP
```

First boot downloads the Squad server + all enabled mods (can be many GB and
take a while). Watch it:
```bash
ssh root@YOUR_SERVER_IP 'journalctl -fu squad-download'
ssh root@YOUR_SERVER_IP 'journalctl -fu squad-vanilla'   # your instance
```

---

## How it works

### Servers are data
`squad-fleet.nix` declares `services.squad-servers.instances.<name>` entries.
Each is plain data: a name, a set of mods, a layer rotation, ports, and optional
voting/SAT/tags. The engine module reads these and, per instance, generates the
`Server.cfg` / `Rcon.cfg` / `Admins.cfg` / `MOTD.cfg` / rotation files, a
systemd unit, and firewall rules — and registers every mod for download.

### Mods compose with `//`
A mod profile is just:
```nix
# mods/steel-division.nix
{
  workshopIds.steel-division = "2432926361";   # VALUE is the workshop ID
  layers = [ "SD_AlBasrah_Invasion_v1" /* … */ ];
}
```
Combine them in a server with attrset-merge:
```nix
mods = sd.workshopIds // sm.workshopIds // sat.workshopIds;
```

> ⚠️ **Profile format gotcha (important):** `workshopIds` must be
> `workshopIds.<name> = "ID"` — the *value* is the numeric ID. The downloader
> does `attrValues mods` to feed SteamCMD, so if you invert it to
> `{ "ID" = "name"; }` it will try to download the *name* (and names with
> spaces split into garbage items, failing the whole download). Match the
> existing profiles.

### Voting
Set `mapRotationMode = "LayerList_Vote"`, give `voteLayers` the pool the cards
may offer, and `voteConfig` the behaviour. **Use the real `VoteConfig.cfg`
keys** (this trips people up):

| Setting | Meaning |
|---|---|
| `LayerOptionsNumber` | number of **map** cards (2–6) |
| `TeamVoteOptionsNumber` | number of **faction** choices per team (2–6) |
| `LayerVoteDuration` / `TeamVote_Duration` | vote durations (s) |
| `LowPlayerCountThreshold` | below this, the low-pop pool is used |
| `FirstLayer` | the layer the server boots on each start |

(`LayerCountPerVote`, `LayerVote_Duration`, etc. are from an older version and
are silently ignored — a common source of "my faction vote is stuck at 4".)

### Squad Admin Tools (SAT)
SAT is unusual: it activates by **booting a SAT init layer first**
(`VoiceConnect_Init`), which modifies subsequent layers, and it's configured via
its own `SquadAdminTools.cfg`. This repo manages that file **create-if-absent**:
your `satConfig` is written once if the file is missing, then SAT owns it (it
regenerates it on updates and you can tune it in-game) and `nixos-rebuild` won't
clobber it. `mods/sat.nix` ships a `compatibleConfig` preset tuned for NVG +
SuperMod + Steel Division (voice/parachutes/shovels on; lighting/weapons/
anti-cheat off). SAT enhances Squad's vanilla vote rather than replacing it
(`VotingVoice = "true"` adds cross-team voice during the vote).

---

## Notes & lessons baked in

These are non-obvious things this config already handles so you don't have to
rediscover them:

- **Binary-advertising / server invisibility.** Unreal resolves `ProjectDir`
  from the running binary's path (`/proc/self/exe`). If the server binary is a
  symlink into a shared install, it reads the *shared* `Server.cfg` and never
  advertises — so the server is invisible in the browser. The engine
  materialises the launcher + `SquadGame/Binaries/Linux` as real files per
  instance to fix this.
- **`MapRotationMode`.** Squad's own wiki recommends `LayerList`; other modes are
  fragile. For voting, `LayerList_Vote` needs the `LayerVoting.cfg` +
  `VoteConfig.cfg` files (this repo generates them). And **always put a known-good
  vanilla layer first** in a modded rotation — a bad first layer can make the
  server refuse joins.
- **`RandomizeAtStart=false`.** `true` is known to break rotation loading; the
  engine sets it false.
- **MOTD formatting.** Base Squad supports only `<a>text</a>` (yellow text) and
  `<a href="url">text</a>` (yellow link) plus plain text. The `<Title1>` /
  `<Yellow1>` / `<Heading1>` tags are from **Squad 44**, a different game — in
  Squad they render as literal text.
- **Parked servers need parked SquadJS.** If a game instance is `enable = false`
  but its SquadJS entry is `enable = true`, SquadJS crash-loops trying to reach a
  dead RCON port (and can burn the Discord login quota). Keep both flags in sync.
- **Mods break on game updates.** Every major Squad release typically requires
  mod authors to re-cook their mods. A clean recovery here: keep a no-mod
  `vanilla` instance to stay online, and re-enable modded instances once their
  mods update (a `systemctl restart squad-download` re-pulls them) — no
  reconfiguration needed.

---

## Secrets

The placeholders inline secrets to keep the example readable. For a real,
public-repo-safe deployment:

1. Add [sops-nix](https://github.com/Mic92/sops-nix) (or agenix) to the flake.
2. Put `rconPassword` and the Discord `token` in an encrypted secrets file.
3. Reference `config.sops.secrets.<name>.path` (read at activation) instead of
   the literal strings in `squad-fleet.nix`.

Never commit a working RCON password or bot token to a public repository — and
if one ever leaks, **rotate it** (regenerate the Discord bot token, change the
RCON password).

---

## Status / compatibility

Built and run against Squad 10.x. Mod workshop IDs and layer names in `mods/`
were verified from the Steam Workshop and in-game; some special layers (and any
mod not yet updated for the current game version) may need their names
re-confirmed via in-game `AdminChangeLayer` autocomplete.

## License

MIT — see [LICENSE](./LICENSE). This is community tooling and is not affiliated
with or endorsed by Offworld Industries. "Squad" and all mods are the property
of their respective owners.
