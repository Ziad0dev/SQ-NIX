# mods/modloader.nix — ModLoader framework by Jhett
# https://steamcommunity.com/sharedfiles/filedetails/?id=3516838562
# ~10 MB framework that injects modded actors into ANY layer (vanilla or
# modded) without custom layers. Addons configure themselves through
# Saved/ModLoader/ModLoader.json — set the instance's `modLoaderMods`
# option and the NixOS module generates that file for you.
# Tagged Voting Compatible + Vanilla Rotation Compatible.
# Addon catalog: ModLoader Suite collection, Workshop id 3523300403.
{
  workshopIds.modloader = "3516838562";
  layers = [ ];   # framework only — adds no layers itself
}
