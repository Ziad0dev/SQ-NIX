# disko.nix — declarative disk layout (EXAMPLE, for nixos-anywhere).
# ════════════════════════════════════════════════════════════════════════════
# Used when provisioning a fresh remote box with `nixos-anywhere`. A simple
# UEFI/GPT single-disk layout: 512M ESP + rest as ext4 root. Adjust `device`
# to your box's disk (often /dev/sda or /dev/nvme0n1 — check with `lsblk`).
#
# If you're deploying to an ALREADY-running NixOS host, you don't use this file;
# it's only read during a from-scratch nixos-anywhere install.

{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";     # CHANGE_ME — verify with lsblk on the target
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  # If your box has a second data disk for the (large) Squad install + mods,
  # uncomment and adjust — then point cfg.stateDir at its mountpoint.
  # disko.devices.disk.data = {
  #   type = "disk";
  #   device = "/dev/sdb";
  #   content = {
  #     type = "gpt";
  #     partitions.data = {
  #       size = "100%";
  #       content = { type = "filesystem"; format = "ext4"; mountpoint = "/var/lib/squad"; };
  #     };
  #   };
  # };
}
