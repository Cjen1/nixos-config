{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  procps,
  ripgrep,
  bubblewrap,
  socat,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.1.220";

  src = ./.;
  nodejs = nodejs_22;

  npmDepsHash = "sha256-8nN99T615uUmbp/arNDYm2HNmr9LmiOgSiFyrKHh4Ko=";

  dontNpmBuild = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper \
      $out/lib/node_modules/anthropic-claude-code-nix/node_modules/.bin/claude \
      $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ alsa-lib ]} \
      --prefix PATH : ${lib.makeBinPath [
        procps
        ripgrep
        bubblewrap
        socat
      ]}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Anthropic Claude Code";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
  };
}
