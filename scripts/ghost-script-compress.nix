{pkgs, ...}:
pkgs.writeShellScriptBin "gs-compress" ''
  ${pkgs.ghostscript}/bin/gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/printer -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$2 $1
''
