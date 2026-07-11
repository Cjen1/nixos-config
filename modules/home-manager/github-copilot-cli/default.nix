{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  autoPatchelfHook,
  pkg-config,
  libsecret,
}:

buildNpmPackage rec {
  pname = "github-copilot-cli";
  version = "1.0.70";

  src = ./.;
  nodejs = nodejs_22;

  npmDepsHash = "sha256-OUcvYZCfuWcSV+z7EH2BlWKAxBwbcV4a4hqmK6Tj/aA=";

  dontNpmBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libsecret
  ];

  postInstall = ''
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/github-copilot-cli-nix/node_modules/.bin/copilot $out/bin/copilot
  '';

  meta = {
    description = "GitHub Copilot coding agent for the terminal";
    homepage = "https://github.com/github/copilot-cli";
    license = lib.licenses.unfree;
    mainProgram = "copilot";
  };
}
