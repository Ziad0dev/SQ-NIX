# Declarative Modded Squad Server Fleet on NixOS

Run a fleet of modded [Squad](https://joinsquad.com/) dedicated servers from one
NixOS config. Edit `squad-fleet.nix`, `nixos-rebuild`, done.

## Deploy

### 1. Clone
```bash
git clone https://github.com/CHANGE_ME/squad-nixos-fleet.git
cd squad-nixos-fleet
```

### 2. Configure
Edit **`squad-fleet.nix`** and replace every `CHANGE_ME_*` (RCON password,
Discord token + admin channel, your SteamID64, Discord invite). Enable the
servers you want with `enable = true;` and set their ports/mods/rotation.

Set your SSH key + hostname in `configuration.nix`. If provisioning a fresh
box, set the disk in `disko.nix`.

> Don't commit real secrets to a public repo — use [sops-nix](https://github.com/Mic92/sops-nix)
> (see `secrets/secrets.example.yaml`).

### 3. Build-test
```bash
git add -A          # flakes only see git-tracked files
nixos-rebuild build --flake .#squad
```

### 4. Deploy

Existing NixOS host:
```bash
git commit -am "configure fleet"
nixos-rebuild switch --flake .#squad --target-host root@YOUR_SERVER_IP
```

Fresh box (provision from scratch):
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#squad root@YOUR_SERVER_IP
```

First boot downloads the Squad server + all enabled mods. Watch it:
```bash
ssh root@YOUR_SERVER_IP 'journalctl -fu squad-download'
ssh root@YOUR_SERVER_IP 'journalctl -fu squad-vanilla'
```

## License

MIT — see [LICENSE](./LICENSE). Not affiliated with Offworld Industries.
