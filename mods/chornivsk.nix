# mods/chornivsk.nix — Chornivsk custom map by Happy
# https://steamcommunity.com/sharedfiles/filedetails/?id=3726472400
# Tagged Voting Compatible + Vanilla Rotation Compatible on the Workshop,
# so it slots into a vanilla-style rotation.
{
  workshopIds.chornivsk = "3726472400";

  layers = [
    "Chornivsk_RAAS_v1"   # verify exact names with `AdminListLayers`
    "Chornivsk_AAS_v1"
  ];
}
