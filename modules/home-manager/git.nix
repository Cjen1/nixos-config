{...}: {
  imports = [];

  programs.git = {
    enable = true;
    delta = {
      enable = true;
    };
    userEmail = "cjj39@cam.ac.uk";
    userName = "cjen1";
    extraConfig = {
      init.defaultBranch = "main";
      core.editor = "vim";
      #core.excludesfile = let gitignore = builtins.toFile "gitignore" (builtins.readFile "./.gitignore"); in "${gitignore}";
      #core.excludesfile = builtins.toFile "gitignore" (builtins.readFile "./.gitignore");
    };
    ignores = [
      "*.swp"
    ];
  };
}
