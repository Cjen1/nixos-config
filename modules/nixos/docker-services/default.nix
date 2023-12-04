{arion, ...}:{
  modules = [ arion.nixosModules.arion ];
  virtualisation.arion.backend = "docker";
}
