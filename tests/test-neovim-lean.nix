let
  flake = builtins.getFlake (toString ../hosts/msft);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  config = (flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs.isRemote = false;
    modules = [ ../hosts/msft/home.nix ];
  }).config;
in
pkgs.runCommand "test-neovim-lean" {} ''
  export HOME="$TMPDIR"
  export XDG_DATA_HOME="$HOME/.local/share"
  mkdir -p "$XDG_DATA_HOME/nvim/site/pack"
  ln -s ${config.xdg.dataFile."nvim/site/pack/hm".source} "$XDG_DATA_HOME/nvim/site/pack/hm"
  ${config.programs.neovim.finalPackage}/bin/nvim --headless -i NONE \
    -u ${config.xdg.configFile."nvim/init.lua".source} \
    '+lua local ok, err = pcall(dofile, "${./test-neovim-lean.lua}"); if not ok then print(err); vim.cmd("cquit 1") end'
  touch "$out"
''
