{...}: {
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = 16;
        normal.family = "Hack Nerd Font";
        bold.family = "Hack Nerd Font";
        italic.family = "Hack Nerd Font";
      };
    };
  };

  home.sessionVariables.TERMINAL = "alacritty";
}
