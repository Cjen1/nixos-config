{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  autoPatchelfHook,
}:

buildNpmPackage rec {
  pname = "t3-code";
  version = "0.0.28";

  src = ./.;
  nodejs = nodejs_22;

  npmDepsHash = "sha256-Rv2HehnVQA963hDca1TZ7LZ72c1bXwn7Ig5cCtf3gnQ=";

  dontNpmBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  postInstall = ''
    rm -r \
      $out/lib/node_modules/t3-code-nix/node_modules/@anthropic-ai/claude-agent-sdk-linux-x64-musl \
      $out/lib/node_modules/t3-code-nix/node_modules/@ff-labs/fff-bin-linux-x64-musl \
      $out/lib/node_modules/t3-code-nix/node_modules/@yuuang/ffi-rs-linux-x64-musl
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/t3-code-nix/node_modules/.bin/t3 $out/bin/t3
  '';

  meta = {
    description = "Minimal web interface for coding agents";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    mainProgram = "t3";
  };
}
