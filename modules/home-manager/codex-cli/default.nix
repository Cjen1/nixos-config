{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  autoPatchelfHook,
  ncurses,
}:

buildNpmPackage rec {
  pname = "codex-cli";
  version = "0.169.0";

  src = ./.;
  nodejs = nodejs_22;

  npmDepsHash = "sha256-M2gQJi2UIiWrIdzCTCBm9I9F4f4V0DWqU+IqDYfQrb0=";

  dontNpmBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    ncurses
  ];

  postInstall = ''
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/openai-codex-cli-nix/node_modules/.bin/codex $out/bin/codex
  '';

  meta = {
    description = "OpenAI Codex CLI";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
  };
}
