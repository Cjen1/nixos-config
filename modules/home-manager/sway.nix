{...}:{
  imports = [
    ./alacritty.nix
  ];
  wayland.windowManager.sway = 
    let modifier = "Mod4";
    in {
      enable = true;
      config = {
        modifier = modifier;
        terminal = "alacritty";
        menu = "wofi --show run";

      };
    };
  
  programs.wofi = {
    enable = true;
    settings = {
      location = "top";
    };
  };
}
