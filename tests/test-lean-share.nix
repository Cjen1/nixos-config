let
  flake = builtins.getFlake (toString ../hosts/msft);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
in
pkgs.runCommand "test-lean-share"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.git
    ];
    leanShareSource = ../modules/home-manager/lean-share.py;
  }
  ''
    export HOME="$TMPDIR"
    export PYTHONDONTWRITEBYTECODE=1
    python3 ${./test-lean-share.py}
    touch "$out"
  ''
