# Helicopter Landing Training by Youshisu — workshop 3309058364.
# Heli flight/landing training: spawn any heli (F9), landing zones with scoring,
# training modes (Free Flight / Orders / Close Air Support). Unmodified helis.
# Small (~9.5MB), actively maintained, works offline + on Linux/Windows servers.
# Layers use HTD_<Map>_AAS_v1 naming. Layer list verified from the workshop page.
{
  workshopId = "3309058364";

  workshopIds.heli-training = "3309058364";

  # All 11 Helicopter Landing Training layers (HTD = Helicopter Training).
  layers = [
    "HTD_AlBasrah_AAS_v1"
    "HTD_BlackCoast_AAS_v1"
    "HTD_Belaya_AAS_v1"
    "HTD_GooseBay_AAS_v1"
    "HTD_Gorodok_AAS_v1"
    "HTD_Harju_AAS_v1"
    "HTD_Mutaha_AAS_v1"
    "HTD_Manicouagan_AAS_v1"
    "HTD_Narva_AAS_v1"
    "HTD_Tallil_AAS_v1"
    "HTD_Yehorivka_AAS_v1"
  ];

  # A small default rotation; the mod is a sandbox so any single layer is fine.
  defaultRotation = [
    "HTD_Yehorivka_AAS_v1"
    "HTD_Tallil_AAS_v1"
    "HTD_GooseBay_AAS_v1"
  ];
}
