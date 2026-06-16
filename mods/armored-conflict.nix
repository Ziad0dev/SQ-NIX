# Armored Conflict — vehicle-on-vehicle combat mod (workshop 3489820789).
# Tank-focused game mode; armor controlled from the gunner's seat. Its layers
# use the AC_<Map>_TRAAS_<v> naming. Voting-compatible. Layer list verified
# from the workshop page (2026-06).
#
# NOTE: at time of writing the workshop page showed a Steam "removed/guidelines"
# banner; the mod still had ~38k subscribers and a live server, but its
# availability could change. Fine for a parked instance.
{
  workshopId = "3489820789";

  workshopIds.armored-conflict = "3489820789";

  # All Armored Conflict layers (TRAAS = the mod's tank-RAAS game mode).
  layers = [
    "AC_Narva_TRAAS_v1"
    "AC_Tallil_TRAAS_v1"
    "AC_Tallil_TRAAS_v2"
    "AC_Yehorivka_TRAAS_v1"
    "AC_Yehorivka_TRAAS_v2"
    "AC_Gorodok_TRAAS_v1"
    "AC_Gorodok_TRAAS_v2"
    "AC_Mutaha_TRAAS_v1"
    "AC_Mutaha_TRAAS_v2"
    "AC_Manicouagan_TRAAS_v1"
    "AC_Manicouagan_TRAAS_v2"
    "AC_BlackCoast_TRAAS_v1"
    "AC_BlackCoast_TRAAS_v2"
  ];

  # A sensible default rotation (a couple of maps); edit to taste.
  defaultRotation = [
    "AC_Tallil_TRAAS_v1"
    "AC_Yehorivka_TRAAS_v1"
    "AC_Gorodok_TRAAS_v1"
  ];
}
