# mods/icm.nix — ICM / IncredibleCrazyMode - Squad Next Generation
# https://steamcommunity.com/sharedfiles/filedetails/?id=3038864732
# 296 layers total (42 RAAS / 92 Invasion / 45 AAS / TerritoryControl /
# Destruction / Skirmish). Updates ~weekly — keep autoUpdate on, and
# re-verify names with `ListLayers` after updates.
# Source: github.com/fantinodavide/SquadLayerList (SDK export).
{
  workshopIds.icm = "3038864732";
  # workshopIds.icm-invasion = "3138071599";  # optional sibling

  layers = [
    "ICM_AlBasrah_RAAS_v1"
    "ICM_Anvil_RAAS_v1"
    "ICM_Anvil_RAAS_v2"
    "ICM_Belaya_RAAS_v1"
    "ICM_BlackCoast_RAAS_v1"
    "ICM_BlackCoast_RAAS_v2"
    "ICM_Chora_RAAS_v1"
    "ICM_Fallujah_RAAS_v1"
    "ICM_Fallujah_RAAS_v2"
    "ICM_FoolsRoad_RAAS_v1"
    "ICM_AlBasrah_AAS_v1"
    "ICM_Anvil_AAS_v1"
    "ICM_Belaya_AAS_v1"
    "ICM_BlackCoast_AAS_v1"
  ];
}
