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
  dark = config.stylix.polarity == "dark";
  pal = (import ../../theme/palette.nix).${if dark then "dark" else "light"};
  accent = "#${pal.accent}";
  # Glass edge: a thin translucent light line on every window, amber on the active one
  edgeActive = "#${pal.accent}cc";
  edgeInactive = "#${pal.glassEdge}${if dark then "1f" else "66"}";
  # Soft, centred shadows that lift the glass off the wallpaper
  shadow = "#${pal.shadow}${if dark then "70" else "26"}";
  shadowWs = "#${pal.shadow}${if dark then "88" else "33"}";
in
{
  home.packages = with pkgs; [
    xwayland-satellite # X11 apps under Niri (picked up automatically)
    wl-clipboard
  ];

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

    // Laptop screen. An external monitor is placed above it automatically
    // (see modules/home/monitors.nix).
    output "eDP-1" {
        position x=0 y=0
    }

    // HP ENVY 27s (4K panel). Matched by name, so it works on any port or dock.
    // Right now the cable/dock only offers up to 2560x1600 (16:10, stretched), so use
    // 2560x1440. Once 4K shows up in `niri msg outputs`, switch to:
    //     mode "3840x2160@60.000"
    //     scale 1.5
    output "HP Inc. HP ENVY 27s 6CM8052GTV" {
        mode "2560x1440@59.951"
        scale 1
    }

    // With a monitor plugged in, closing the lid turns the laptop screen off
    switch-events {
        lid-close { spawn "niri" "msg" "output" "eDP-1" "off"; }
        lid-open { spawn "niri" "msg" "output" "eDP-1" "on"; }
    }


    layout {
        gaps 14
        center-focused-column "never"
        background-color "transparent"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        default-column-width { proportion 0.5; }

        focus-ring {
            off
        }
        // Liquid glass edge on every window; the active one glows amber
        border {
            on
            width 1
            active-color "${edgeActive}"
            inactive-color "${edgeInactive}"
            urgent-color "${c.base08}"
        }
        shadow {
            on
            softness 30
            spread 0
            offset x=0 y=10
            draw-behind-window true
            color "${shadow}"
        }
        tab-indicator {
            hide-when-single-tab
            place-within-column
            gap 6
            width 3
            active-color "${accent}"
            inactive-color "${c.base03}"
        }
        struts {
            top 2
        }
    }

    // Wallpaper also shows behind the overview, blurred
    overview {
        zoom 0.5
        backdrop-color "${c.base00}"
        workspace-shadow {
            softness 26
            spread 4
            offset x=6 y=10
            color "${shadowWs}"
        }
    }

    // Frosted glass: strong blur, slight saturation boost like liquid glass
    blur {
        passes 3 // 3 passes with a wider offset: about the same softness, a quarter less GPU work at 4K
        offset 5.5
        noise 0.02
        saturation 1.35
    }

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png"

    hotkey-overlay {
        skip-at-startup
    }

    // Springs: windows settle with a slight bounce instead of sliding linearly
    animations {
        window-open {
            spring damping-ratio=0.7 stiffness=560 epsilon=0.0001
        }
        window-close {
            duration-ms 160
            curve "ease-out-quad"
        }
        window-movement {
            spring damping-ratio=0.75 stiffness=640 epsilon=0.0001
        }
        window-resize {
            spring damping-ratio=0.75 stiffness=620 epsilon=0.0001
        }
        workspace-switch {
            spring damping-ratio=0.85 stiffness=900 epsilon=0.0001
        }
        horizontal-view-movement {
            spring damping-ratio=0.8 stiffness=760 epsilon=0.0001
        }
        overview-open-close {
            spring damping-ratio=0.8 stiffness=700 epsilon=0.0001
        }
    }

    // Rounded glass panes; windows you're not using step back slightly
    window-rule {
        geometry-corner-radius 18
        clip-to-geometry true
        opacity 0.97
        draw-border-with-background false
    }
    window-rule {
        match is-active=true
        opacity 1.0
    }
    // Video and screen sharing stay fully opaque
    window-rule {
        match title="(?i)youtube|meet|teams|zoom"
        opacity 1.0
    }

    // Terminals are frosted glass: see-through with the wallpaper blurred behind
    window-rule {
        match app-id="^com\\.mitchellh\\.ghostty$"
        background-effect {
            blur true
        }
    }

    // Shortcut cheatsheet (Mod+/ or Mod+F1)
    window-rule {
        match app-id="^dev\\.cheatsheet$"
        match app-id="^dev\\.codex$"
        open-floating true
        default-column-width { fixed 1040; }
        default-window-height { fixed 840; }
        draw-border-with-background false
        background-effect {
            blur true
            xray false
        }
    }

    // Floating pickers and dialogs
    window-rule {
        match app-id="pavucontrol"
        match app-id="nm-connection-editor"
        match title="^Picture-in-Picture$"
        open-floating true
    }

    window-rule {
        match is-floating=true
        shadow {
            softness 40
            offset x=8 y=14
        }
    }

    // Noctalia's blurred wallpaper copy sits behind the overview
    layer-rule {
        match namespace="^noctalia-backdrop"
        place-within-backdrop true
    }

    // Frosted glass behind Noctalia's bar, panels, notifications and popups
    layer-rule {
        match namespace="^noctalia-bar-"
        match namespace="^noctalia-panel$"
        match namespace="^noctalia-attached-panel$"
        match namespace="^noctalia-notification$"
        match namespace="^noctalia-osd$"
        match namespace="^noctalia-window-switcher$"
        match namespace="^noctalia-desktop-widget-"
        background-effect {
            blur true
        }
    }

    // Noctalia settings window
    window-rule {
        match app-id="dev.noctalia.Noctalia"
        open-floating true
        default-column-width { fixed 1080; }
        default-window-height { fixed 860; }
    }

    // Lets Noctalia notification actions focus the right window
    debug {
        honor-xdg-activation-with-invalid-serial
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }
        Mod+M hotkey-overlay-title="Focus session (Vesna meditates)" { spawn "focus"; }
        Mod+Shift+B hotkey-overlay-title="Morning brief" { spawn "brief"; }
        Mod+Shift+A hotkey-overlay-title="Bestiary" { spawn "bestiary"; }
        Mod+Alt+W hotkey-overlay-title="Next wallpaper" { spawn "wall" "next"; }
        Mod+Alt+Shift+W hotkey-overlay-title="Previous wallpaper" { spawn "wall" "prev"; }
        Mod+G hotkey-overlay-title="Witcher's Codex (agent guide)" { spawn "ghostty" "--class=dev.codex" "--title=Codex" "-e" "guide"; }
        Mod+Slash hotkey-overlay-title="Cheatsheet" { spawn "ghostty" "--class=dev.cheatsheet" "--title=Cheatsheet" "-e" "cheatsheet"; }
        Mod+F1 hotkey-overlay-title=null { spawn "ghostty" "--class=dev.cheatsheet" "--title=Cheatsheet" "-e" "cheatsheet"; }

        // Apps
        Mod+Return hotkey-overlay-title="Terminal" { spawn "ghostty"; }
        Mod+Space hotkey-overlay-title="Launcher" { spawn-sh "noctalia msg panel-toggle launcher"; }
        Mod+S hotkey-overlay-title="Control centre" { spawn-sh "noctalia msg panel-toggle control-center"; }
        Mod+Shift+S hotkey-overlay-title="Shell settings" { spawn-sh "noctalia msg settings-toggle"; }
        Mod+N hotkey-overlay-title="Notifications" { spawn-sh "noctalia msg panel-toggle control-center"; }
        Mod+B hotkey-overlay-title="Chrome" { spawn "google-chrome-stable"; }
        Mod+E hotkey-overlay-title="Files" { spawn "nautilus"; }
        Mod+V hotkey-overlay-title="Clipboard history" { spawn-sh "noctalia msg panel-toggle clipboard"; }
        Mod+Shift+T hotkey-overlay-title="Toggle light/dark" { spawn "ghostty" "-e" "theme" "toggle"; }
        Mod+Shift+G hotkey-overlay-title="Terminal frost / dark" { spawn "term" "toggle"; }
        Mod+Shift+W hotkey-overlay-title="Move desktop widgets" { spawn-sh "noctalia msg desktop-widgets-toggle-edit"; }
        Mod+Escape hotkey-overlay-title="Lock" { spawn-sh "noctalia msg session lock"; }
        Super+Alt+L hotkey-overlay-title=null { spawn-sh "noctalia msg session lock"; }

        // Media keys (Noctalia shows the on-screen popup)
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "noctalia msg volume-up"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "noctalia msg volume-down"; }
        XF86AudioMute allow-when-locked=true { spawn-sh "noctalia msg volume-mute"; }
        XF86AudioMicMute allow-when-locked=true { spawn-sh "noctalia msg mic-mute"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn-sh "noctalia msg brightness-up"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn-sh "noctalia msg brightness-down"; }

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

        // Monitors (external sits above the laptop)
        Mod+Shift+Up { focus-monitor-up; }
        Mod+Shift+Down { focus-monitor-down; }
        Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }
        Mod+Shift+Alt+Up { move-workspace-to-monitor-up; }
        Mod+Shift+Alt+Down { move-workspace-to-monitor-down; }

        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
        Mod+WheelScrollRight { focus-column-right; }
        Mod+WheelScrollLeft { focus-column-left; }

        // Screenshots
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // Session
        Mod+Shift+E hotkey-overlay-title="Session menu" { spawn-sh "noctalia msg panel-toggle session"; }
        Mod+Shift+Ctrl+E { quit; }
        Mod+Shift+P { power-off-monitors; }
    }
  '';
}
