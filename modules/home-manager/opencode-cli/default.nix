{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  autoPatchelfHook,
  makeBinaryWrapper,
  ripgrep,
}:

buildNpmPackage rec {
  pname = "opencode-cli";
  version = "1.18.4";

  src = ./.;
  nodejs = nodejs_22;

  npmDepsHash = "sha256-R8zWbybPkl0l6m0vQuq/0lh2M9wA8cEsRF+EyuKAGsg=";

  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  postInstall = ''
    rm -r \
      $out/lib/node_modules/opencode-cli-nix/node_modules/opencode-linux-x64 \
      $out/lib/node_modules/opencode-cli-nix/node_modules/opencode-linux-x64-musl \
      $out/lib/node_modules/opencode-cli-nix/node_modules/opencode-linux-x64-baseline-musl
    mkdir -p $out/bin
    makeBinaryWrapper \
      $out/lib/node_modules/opencode-cli-nix/node_modules/opencode-linux-x64-baseline/bin/opencode \
      $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set OPENCODE_DISABLE_AUTOUPDATE true
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    mainProgram = "opencode";
  };
}
