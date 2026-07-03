{...}: {
  programs.alacritty = {
    enable = true;
    settings = {
      window.decorations_theme_variant = "Dark";

      font = {
        size = 14;
        normal.family = "Hack Nerd Font";
        bold.family = "Hack Nerd Font";
        italic.family = "Hack Nerd Font";
      };
    };
  };

  home.sessionVariables.TERMINAL = "alacritty";
}
