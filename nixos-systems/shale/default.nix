{inputs, pkgs, lib, config, ...}:{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-wsl.nixosModules.wsl
    #../../modules/nixos/greetd.nix
    #../../modules/nixos/cam-vpn
    #../../modules/nixos/cam-vpn/desktop_items.nix
    #../../modules/nixos/qmk.nix
    #../../modules/nixos/audio.nix
    #../../modules/nixos/bluetooth.nix
    #../../modules/nixos/cambridge.nix
    #../../modules/nixos/persist.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = "cjen1";

  nixpkgs.config.allowUnfree = true;
  nix = {
    registry = lib.mapAttrs (_: value: {flake = value; }) inputs;

    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  time.timeZone = "Europe/London";

  networking.hostName = "shale";
  networking.networkmanager.enable = true;

  environment.systemPackages = 
    with pkgs; [
    vim 
    networkmanager
  ];

  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;
  users.users.cjen1 = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "pulse-access" "docker" "adbusers" ]; # Enable ‘sudo’ for the user.
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs; };
    users = {
      cjen1 = import ../../home-manager/shale;
    };
  };

  security.polkit.enable = true;

  system.stateVersion = "23.10";
}
