# Terminal: two looks, switched with Mod+Shift+G or `term toggle|frost|dark`,
# independent of the system light/dark theme:
#   frost  white frosted glass, dark text (default)
#   dark   night-slate smoked glass, very see-through, light text
# Niri blurs the wallpaper behind both. Prompt and tools use the terminal's ANSI colours,
# so they read well in either look.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  palette = import ../../theme/palette.nix;
  p = palette.light;
  n = palette.dark;
  h = v: "#${v}";

  # The `term` switch writes this file; Ghostty includes it after the main config
  modeFile = "${config.xdg.configHome}/ghostty/mode";

  term = pkgs.writeShellApplication {
    name = "term";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      procps
      systemd
    ];
    text = ''
      f="${modeFile}"
      current=frost
      grep -q '^theme = night' "$f" 2>/dev/null && current=dark
      want=''${1:-toggle}
      if [ "$want" = toggle ]; then
        if [ "$current" = dark ]; then want=frost; else want=dark; fi
      fi
      mkdir -p "$(dirname "$f")"
      case "$want" in
        dark) printf 'theme = night\nbackground-opacity = 0.40\n' >"$f" ;;
        frost) : >"$f" ;;
        *) echo "usage: term [toggle|frost|dark]"; exit 1 ;;
      esac
      systemctl --user kill --kill-whom=main -s USR2 app-com.mitchellh.ghostty.service 2>/dev/null || true
      pkill -USR2 -f '\.ghostty-wrapped' 2>/dev/null || true
      echo "Terminal: $want"
    '';
  };
in
{
  # Ghostty runs as a background service and only reads its config at start.
  # After every rebuild, ask it to reload so new colours and settings apply at once.
  home.activation.reloadGhostty = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.systemd}/bin/systemctl --user kill --kill-whom=main -s USR2 app-com.mitchellh.ghostty.service 2>/dev/null || true
    ${pkgs.procps}/bin/pkill -USR2 -f '\.ghostty-wrapped' 2>/dev/null || true
  '';

  # These would paint the dark system palette onto a light terminal
  stylix.targets = {
    ghostty.enable = false;
    starship.enable = false;
    bat.enable = false;
    btop.enable = false;
    fzf.enable = false;
    lazygit.enable = false;
    yazi.enable = false;
  };

  home.packages = [ term ];

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    themes.frost = {
      background = h p.base00;
      foreground = h p.base05;
      cursor-color = h p.accent;
      cursor-text = h p.onAccent;
      selection-background = h p.base02;
      selection-foreground = h p.base05;
      palette = [
        "0=${h p.base05}"
        "1=${h p.base08}"
        "2=${h p.base0B}"
        "3=${h p.base0A}"
        "4=${h p.base0D}"
        "5=${h p.base0E}"
        "6=${h p.base0C}"
        "7=${h p.base03}"
        "8=${h p.base04}"
        "9=${h p.base09}"
        "10=${h p.base0B}"
        "11=${h p.base0F}"
        "12=${h p.accent}"
        "13=${h p.base0E}"
        "14=${h p.base0C}"
        "15=${h p.base07}"
      ];
    };

    # Dark smoked glass: same colour roles as frost, so the prompt looks alike in both
    themes.night = {
      background = h n.base00;
      foreground = h n.base06;
      cursor-color = h n.accent;
      cursor-text = h n.onAccent;
      selection-background = h n.base02;
      selection-foreground = h n.base07;
      palette = [
        "0=${h n.base01}"
        "1=${h n.base08}"
        "2=${h n.base0B}"
        "3=${h n.base0A}"
        "4=${h n.base0D}"
        "5=${h n.base0E}"
        "6=${h n.base0C}"
        "7=${h n.base05}"
        "8=${h n.base04}"
        "9=${h n.base09}"
        "10=${h n.base0B}"
        "11=${h n.base0F}"
        "12=${h n.accent}"
        "13=${h n.base0E}"
        "14=${h n.base0C}"
        "15=${h n.base07}"
      ];
    };

    settings = {
      theme = "frost";
      font-family = config.stylix.fonts.monospace.name;
      font-size = 11;
      background-opacity = 0.68; # milky glass; the blur comes from Niri
      window-padding-x = 22;
      window-padding-y = 18;
      adjust-cell-height = "20%"; # airier lines
      window-padding-balance = true;
      window-decoration = false;
      cursor-style = "bar";
      confirm-close-surface = false;
      copy-on-select = "clipboard";
      shell-integration-features = "no-cursor";
      config-file = "?${modeFile}"; # dark look when switched on (? = fine if missing)
    };
  };

  programs.bat.config.theme = "ansi";
  programs.btop.settings = {
    color_theme = "TTY";
    theme_background = false;
  };
  # delta detects whether the terminal is light or dark by itself
  programs.delta.options.syntax-theme = "ansi";
}
