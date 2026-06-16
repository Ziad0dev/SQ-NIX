# mods/default.nix — import all mod profiles as one attrset.
#   let mods = import ./mods; in
#   mods.steel-division.workshopIds // mods.icm.workshopIds
{
  steel-division  = import ./steel-division.nix;
  supermod        = import ./supermod.nix;
  icm             = import ./icm.nix;
  warzone         = import ./warzone.nix;
  chornivsk       = import ./chornivsk.nix;
  modloader       = import ./modloader.nix;
  dynamic-weather = import ./dynamic-weather.nix;
  task-force-zero = import ./task-force-zero.nix;
  armored-conflict = import ./armored-conflict.nix;
  sat              = import ./sat.nix;
  galactic-contention = import ./galactic-contention.nix;
  heli-training    = import ./heli-training.nix;
}
