# Squad Admin Tools (SAT / "VoiceConnect") — workshop 3193475024.
# Admin tools + cross-team voice + parachutes + shovels-for-all + more, all
# driven by its own SquadAdminTools.cfg (see `satConfig` in squad-servers.nix).
#
# ACTIVATION IS DIFFERENT FROM OTHER MODS: SAT activates by BOOTING one of its
# init layers (VoiceConnect_Init, or SAT_Gorodok_*/SAT_Tallil_*), which then
# modifies all subsequent layers. So the server's FIRST rotation entry must be
# a SAT init layer. After a server restart you must re-run the init layer.
#
# Supports SuperMod / SteelDivision / GlobalEscalation. For SD compatibility set
# OverrideGamemodeState = limited in satConfig. Actively developed & sometimes
# unstable — author's Discord: discord.gg/vzTdY9SbEb. Updated for Squad v10.4.
{
  workshopId = "3193475024";

  workshopIds.sat = "3193475024";

  # SAT init / seed layers (booting one of these activates SAT for the session).
  initLayers = [
    "VoiceConnect_Init"          # generic init — activates SAT, skips to next layer
    "SAT_Gorodok_SeedCAS_v1"     # SAT seed layer (Gorodok)
    "SAT_Tallil_Seed_v1"         # SAT seed layer (Tallil, bots/helis)
  ];

  # The "most compatible" SAT settings for an NVG + SuperMod + Steel Division
  # stack: the three wanted features ON (voice, parachutes, shovels); everything
  # that touches lighting / weapons / combat-feel / anti-cheat OFF, because
  # SuperMod/SD/NVG already own those domains and stacking SAT's versions invites
  # conflicts (and the changelog flags GI/anti-cheat as crash-prone).
  compatibleConfig = {
    OverrideGamemodeState  = "limited";   # SD compatibility (changelog v20.0.5)
    CrossTeamVoiceEnabled  = "true";       # wanted feature
    SATParachutes          = "true";       # wanted feature
    ShovelsForAll          = "engineer";   # wanted feature — everyone gets eng shovel
    SATGraphics            = "false";       # OFF — don't alter lighting on NVG layers
    Graphics_DisableGI     = "false";       # OFF — author says it crashes
    SATWeapons             = "false";       # OFF — SuperMod already overhauls weapons
    SATAntiCheat           = "false";       # OFF — author says server-side issues
  };
}
