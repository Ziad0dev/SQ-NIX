# hardware-configuration.nix — PLACEHOLDER.
# ════════════════════════════════════════════════════════════════════════════
# This file is HARDWARE-SPECIFIC and must be generated ON YOUR machine. Do NOT
# use this placeholder as-is — it will not boot your hardware.
#
# On the target box (or in the nixos-anywhere installer), generate the real one:
#   nixos-generate-config --root /mnt          # during install
#   # or, on a running system:
#   nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# Then commit YOUR generated file in place of this placeholder. It will contain
# your real filesystems, kernel modules, and CPU microcode settings.
#
# (If you provision with disko + nixos-anywhere, disko.nix defines the
# filesystems and you can keep this minimal — but you still need the correct
# boot modules for your hardware.)

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # EXAMPLE values — REPLACE with your generated hardware config.
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];      # or kvm-intel
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Filesystems are normally filled in by nixos-generate-config (or provided by
  # disko.nix). Left empty here on purpose so you don't accidentally ship a
  # wrong layout.
}
