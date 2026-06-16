# mods/dynamic-weather.nix — Dynamic Weather System by Fosh
# https://steamcommunity.com/sharedfiles/filedetails/?id=3562774788
# Ultra Dynamic Sky & Weather for Squad. REQUIRES ModLoader (compose this
# profile together with mods/modloader.nix). Works on all layers per the
# author, so a vanilla rotation is fine.
{
  workshopIds.dynamic-weather = "3562774788";
  layers = [ ];   # weather overlay — adds no layers itself

  # Path string ModLoader needs in ModLoader.json (random-weather variant);
  # see the mod page for other presets:
  modLoaderPath = "/DynamicWeatherSystem/BP_Squad_UltraDynamicWeather_01_Random.BP_Squad_UltraDynamicWeather_01_Random_C";
}
