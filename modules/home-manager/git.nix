{...}: {
  imports = [];

  programs.git = {
    enable = true;
    ignores = [
      "*.swp"
      ".worktrees"
    ];
    settings = {
      user.email = "cjjensen01@aol.com";
      user.name = "cjen1";
      init.defaultBranch = "main";
      core.editor = "vim";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
