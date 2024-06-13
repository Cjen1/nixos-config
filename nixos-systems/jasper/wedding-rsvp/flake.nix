{
  description = "";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, ...}:
  flake-utils.lib.eachDefaultSystem (system:
  let 
    pkgs = nixpkgs.legacyPackages.${system};
    python = pkgs.python3.withPackages (ps: [ps.flask]);
  in {
    devShell = pkgs.mkShell {
      buildInputs = [python];
    };
  });
}
