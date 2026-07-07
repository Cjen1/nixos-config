{ inputs, ... }:
let
  dataDir = "/data/tasks/ps-todos/mnt";
in {
  imports = [
    inputs.ps-todos.nixosModules.default
  ];

  services.ps-todos = {
    enable = true;
    user = "cjen1";
    group = "users";
    createUser = false;
    port = 5000;
    dataDir = "${dataDir}/amrg";
    dashboardsFile = "${dataDir}/config.json";
  };
}
