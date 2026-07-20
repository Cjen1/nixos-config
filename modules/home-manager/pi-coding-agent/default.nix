{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  autoPatchelfHook,
}:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.80.10";

  src = ./.;
  nodejs = nodejs_22;

  npmDepsHash = "sha256-CQfQOLXBOYlQ0KWn2UTPdUbxDkB9RPx0ObPvVVmX0r8=";
  npmDepsFetcherVersion = 2;

  dontNpmBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  postInstall = ''
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/pi-coding-agent-nix/node_modules/.bin/pi $out/bin/pi
  '';

  meta = {
    description = "Minimal terminal coding agent";
    homepage = "https://github.com/earendil-works/pi";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
