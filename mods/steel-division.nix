# mods/steel-division.nix — modern special-forces mod (NVG, thermals, FPV)
# https://steamcommunity.com/sharedfiles/filedetails/?id=2432926361
# 110 layers total (22 RAAS / 57 Invasion / 7 AAS / Skirmish / Seed).
# Names from github.com/fantinodavide/SquadLayerList (SDK export) — an
# older-SDK snapshot, so verify in-game with `ListLayers` after mod updates.
{
  workshopIds.steel-division = "2432926361";

  layers = [
    "SD_AlBasrah_RAAS_v1"
    "SD_AlBasrah_RAAS_v2"
    "SD_Belaya_RAAS_v1"
    "SD_Belaya_RAAS_v2"
    "SD_BlackCoast_RAAS_v1"
    "SD_BlackCoast_RAAS_v2"
    "SD_Chora_RAAS_v1"
    "SD_GooseBay_RAAS_v1"
    "SD_Gorodok_RAAS_v1"
    "SD_Gorodok_RAAS_v2"
    "SD_AlBasrah_Invasion_v1"
    "SD_AlBasrah_Invasion_v2"
    "SD_AlBasrah_Invasion_N_USSFvRED"
    "SD_Anvil_Invasion_v1"
  ];
}
