{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  autoPatchelfHook,
  pkg-config,
  libsecret,
  webkitgtk_4_1,
  gtk3,
  cairo,
  gdk-pixbuf,
  libsoup_3,
  wayland,
  dbus,
  xdotool,
}:

buildNpmPackage rec {
  pname = "github-copilot-cli";
  version = "1.0.83";

  src = ./.;
  nodejs = nodejs_22;

  npmDepsHash = "sha256-A3UP11le4D0xxequZbEPRsFdGy2uwRqpTFDsOQ98rKw=";

  dontNpmBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libsecret
    webkitgtk_4_1
    gtk3
    cairo
    gdk-pixbuf
    libsoup_3
    wayland
    dbus
    xdotool
  ];

  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

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
