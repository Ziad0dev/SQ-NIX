{
  description = "Declarative modded Squad dedicated server fleet on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # disko + nixos-anywhere let you provision a bare remote box declaratively.
    # Optional — if you already have a running NixOS host, you don't need these
    # and can deploy with plain `nixos-rebuild switch --target-host`.
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.squad = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./disko.nix              # disk layout (used by nixos-anywhere; harmless otherwise)
          ./configuration.nix      # host config -> imports ./squad-fleet.nix
        ];
      };
    };
}
