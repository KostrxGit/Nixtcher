# Niri config is plain KDL with palette colours filled in.
# Niri reloads it automatically when the file changes.
# Check it after edits with: niri validate
{
  config,
  pkgs,
  settings,
  ...
}:
let
  c = config.lib.stylix.colors.withHashtag;
in
{
  home.packages = with pkgs; [
    xwayland-satellite # X11 apps under Niri (picked up automatically)
    swaybg
    brightnessctl
    wl-clipboard
    cliphist
  ];

  # Solid-colour background until a wallpaper is chosen
  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Background";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swaybg}/bin/swaybg -c '${c.base00}'";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  services.cliphist.enable = true;

  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "${settings.keyboardLayout}"
            }
            numlock
        }
        touchpad {
            tap
            natural-scroll
            dwt
        }
        focus-follows-mouse max-scroll-amount="0%"
    }

    // The four suits: Mod+1..4. More workspaces appear as needed.
    workspace "spades"
    workspace "hearts"
    workspace "diamonds"
    workspace "clubs"

    layout {
        gaps 12
        center-focused-column "never"
        background-color "${c.base00}"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        default-column-width { proportion 0.5; }

        // Active window = gold ring, like a chip edge
        focus-ring {
            width 2
            active-color "${c.base0A}"
            inactive-color "${c.base02}"
            urgent-color "${c.base08}"
        }
        border {
            off
        }
        shadow {
            off
        }
        tab-indicator {
            active-color "${c.base0A}"
            inactive-color "${c.base03}"
        }
    }

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png"

    hotkey-overlay {
        skip-at-startup
    }

    window-rule {
        geometry-corner-radius 8
        clip-to-geometry true
    }

    // Floating pickers and dialogs
    window-rule {
        match app-id="pavucontrol"
        match app-id="nm-connection-editor"
        match title="^Picture-in-Picture$"
        open-floating true
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Apps
        Mod+Return hotkey-overlay-title="Terminal" { spawn "ghostty"; }
        Mod+Space hotkey-overlay-title="Launcher" { spawn "fuzzel"; }
        Mod+B hotkey-overlay-title="Chrome" { spawn "google-chrome-stable"; }
        Mod+E hotkey-overlay-title="Files" { spawn "nautilus"; }
        Mod+V hotkey-overlay-title="Clipboard history" { spawn "sh" "-c" "cliphist list | fuzzel --dmenu --prompt='♣ Clipboard  ' | cliphist decode | wl-copy"; }
        Mod+Shift+T hotkey-overlay-title="Toggle light/dark" { spawn "ghostty" "-e" "theme" "toggle"; }
        Super+Alt+L hotkey-overlay-title="Lock" { spawn "loginctl" "lock-session"; }

        // Media keys
        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05+" "-l" "1.0"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05-"; }
        XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }

        // Windows
        Mod+Q repeat=false { close-window; }
        Mod+O repeat=false { toggle-overview; }

        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up { focus-window-up; }
        Mod+Down { focus-window-down; }
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+K { focus-window-up; }
        Mod+J { focus-window-down; }

        Mod+Ctrl+Left { move-column-left; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+Up { move-window-up; }
        Mod+Ctrl+Down { move-window-down; }
        Mod+Ctrl+H { move-column-left; }
        Mod+Ctrl+L { move-column-right; }
        Mod+Ctrl+K { move-window-up; }
        Mod+Ctrl+J { move-window-down; }

        Mod+Home { focus-column-first; }
        Mod+End { focus-column-last; }

        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+BracketLeft { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+C { center-column; }
        Mod+W { toggle-column-tabbed-display; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }
        Mod+T { toggle-window-floating; }

        // Workspaces (vertical)
        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+U { focus-workspace-down; }
        Mod+I { focus-workspace-up; }
        Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
        Mod+Ctrl+Page_Up { move-column-to-workspace-up; }
        Mod+Ctrl+U { move-column-to-workspace-down; }
        Mod+Ctrl+I { move-column-to-workspace-up; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }

        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
        Mod+WheelScrollRight { focus-column-right; }
        Mod+WheelScrollLeft { focus-column-left; }

        // Screenshots
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // Session
        Mod+Shift+E { quit; }
        Mod+Shift+P { power-off-monitors; }
    }
  '';
}
