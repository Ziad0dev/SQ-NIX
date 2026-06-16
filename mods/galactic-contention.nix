# Galactic Contention — total-conversion Clone Wars mod (workshop 2428425228).
# A completely different game from milsim: 20+ maps, 175+ layers, 150+ unit
# types, 15+ factions, GC_<Map> layer naming.
#
# ⚠️ IMPORTANT CAVEATS (as of 2026-06, Squad 10.5):
#   * NOT UPDATED for 10.5 (nor 10.4) — the GC team is doing a full engine
#     upgrade, so it will NOT load on a current server until they re-cook it.
#     Keep this instance PARKED until GC announces 10.5 support.
#   * HUGE: ~46 GB download. Make sure the box has disk headroom before enabling.
#   * Total conversion — its own layers/factions; nothing shared with your
#     milsim stack. Run it as its own standalone server, never mixed with SPM/SD.
#   * Photosensitive-epilepsy warning on the mod itself.
#   * Support / server template: discord.gg/galacticcontention ;
#     github.com/Buff-oG/GC-Server-Conf-Template
{
  workshopId = "2428425228";

  workshopIds.galactic-contention = "2428425228";

  # GC layers are many (175+) and use GC_<Map>_<Mode> naming. Pull the current
  # list in-game via `AdminChangeLayer GC_` autocomplete once GC is 10.5-ready;
  # these are placeholders to be confirmed against the updated mod.
  layers = [
    # confirm exact names from in-game autocomplete after GC updates for 10.5
  ];

  defaultRotation = [
    # set once GC is 10.5-ready and you've confirmed layer names
  ];
}
