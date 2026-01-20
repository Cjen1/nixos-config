{...}: {
  imports = [];

  programs.git = {
    enable = true;
    ignores = [
      "*.swp"
    ];
    settings = {
      user = {
        email = "cjjensen01@aol.com";
        name = "cjen1";
      };
      init.defaultBranch = "main";
      core.editor = "vim";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
