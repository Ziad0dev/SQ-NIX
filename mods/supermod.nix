# mods/supermod.nix — Tactical Collective SuperMod (32 factions)
# https://steamcommunity.com/sharedfiles/filedetails/?id=3293347373
# 248 layers total, incl. RVAAS/Frontline/PreCap modes and 32 GoingDark
# night layers. Names from github.com/fantinodavide/SquadLayerList (SDK
# export) — verify with `ListLayers` after mod updates.
{
  workshopIds.supermod = "3293347373";

  layers = [
    "SU_Douentza_AAS_v1"
    "SU_Douentza_RAAS_v1"
    "SU_GooseBay_AAS_v1"
    "SU_GooseBay_RAAS_v1"
    "SU_GooseBay_RAAS_v2"
    "SU_Manicouagan_AAS_v1"
    "SU_Manicouagan_AAS_v2"
    "SU_Manicouagan_AAS_v3"
    "SU_Manicouagan_RAAS_v1"
    "SU_Manicouagan_RAAS_v2"
    "SU_Johat_RAAS_v1"
    "SU_Sanxian_AAS_v1"
  ];

  # "Going Dark" — SuperMod's built-in NVG night layer set (32 total)
  darkLayers = [
    "SU_GoingDark_Sanxian_Invasion_v2"
    "SU_GoingDark_Kamdesh_RVAAS_v1"
    "SU_GoingDark_Kohat_AAS_v1"
    "SU_GoingDark_Lashkar_RVAAS_v1"
    "SU_GoingDark_Yehorivka_RAAS_v1"
    "SU_GoingDark_Yehorivka_RVAAS_v1"
    "SU_GoingDark_Fallujah_AAS_v1"
    "SU_GoingDark_Fallujah_RAAS_v1_PreCap"
    "SU_GoingDark_Tallil_RAAS_v1"
    "SU_GoingDark_Tallil_RAAS_v1_PreCap"
    "SU_GoingDark_Harju_Invasion_v1"
    "SU_GoingDark_Gorodok_Invasion_v1"
  ];
}
