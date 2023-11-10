{pkgs, ...}: {

  # Copied from https://github.com/jeffa5/nix-home/blob/f11d867fe1a5804877416fe7b87b85214dc2036b/packages/sway-scripts/default.nix#L26
  screenshot = let
    wofi = "${pkgs.wofi}/bin/wofi";
    slurp = "${pkgs.slurp}/bin/slurp";
    grim = "${pkgs.grim}/bin/grim";
    notify-send = "${pkgs.libnotify}/bin/notify-send";
    grimshot = "${pkgs.sway-contrib.grimshot}/bin/grimshot";
    convert = "${pkgs.imagemagick}/bin/convert";
  in
    pkgs.writeShellScriptBin "sway-screenshot" ''
      # if wofi is running, kill it
      pgrep wofi && pkill wofi && exit 0

      inputs=$(printf "Focused output\nAll outputs\nRegion\nFocused window\nWindow\nColour Picker")

      selection=$(echo "''$inputs" | ${wofi} --dmenu -p "screenshot" -i)

      PICTURE_DIR="$HOME/Pictures/screenshots/"
      PICTURE_FILE="$PICTURE_DIR$(date +'%Y-%m-%d-%H%M%S_screenshot.png')"

      destination() {
          printf "File\nClipboard" | ${wofi} --dmenu -p "Destination" -i
      }

      case "$selection" in
      "Focused output")
          dest=$(destination)
          case "$dest" in
          "File")
              ${grimshot} --notify save output "$PICTURE_FILE"
              ;;
          "Clipboard")
              ${grimshot} --notify copy output
              ;;
          esac
          ;;

      "All outputs")
          dest=$(destination)
          case "$dest" in
          "File")
              ${grimshot} --notify save screen "$PICTURE_FILE"
              ;;
          "Clipboard")
              ${grimshot} --notify copy screen
              ;;
          esac
          ;;

      "Region")
          dest=$(destination)
          case "$dest" in
          "File")
              ${grimshot} --notify save area "$PICTURE_FILE"
              ;;
          "Clipboard")
              ${grimshot} --notify copy area
              ;;
          esac
          ;;

      "Focused window")
          dest=$(destination)
          case "$dest" in
          "File")
              ${grimshot} --notify save active "$PICTURE_FILE"
              ;;
          "Clipboard")
              ${grimshot} --notify copy active
              ;;
          esac
          ;;

      "Window")
          dest=$(destination)
          case "$dest" in
          "File")
              ${grimshot} --notify save window "$PICTURE_FILE"
              ;;
          "Clipboard")
              ${grimshot} --notify copy window
              ;;
          esac
          ;;

      "Colour Picker")
          colour=$(${grim} -g "$(${slurp} -p)" -t ppm - | ${convert} - -format '%[pixel:p{0,0}]' txt:- | sed -n 2p | awk '{ print $3 }')
          ${notify-send} --app-name screenshot "Colour Picker" "$colour"
          ;;
      esac
    '';
}
