# Waybar: workspaces as card suits, chip-shaped modules.
{ config, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
  font = config.stylix.fonts.monospace.name;
in
{
  stylix.targets.waybar.enable = false; # custom style below

  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.main = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 6;

      modules-left = [
        "niri/workspaces"
        "niri/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "network"
        "pulseaudio"
        "power-profiles-daemon"
        "battery"
      ];

      "niri/workspaces" = {
        format = "{icon}";
        sort-by-name = false; # keep spades, hearts, diamonds, clubs order
        format-icons = {
          spades = "♠";
          hearts = "<span color='${c.base08}'>♥</span>";
          diamonds = "<span color='${c.base08}'>♦</span>";
          clubs = "♣";
          default = "●";
        };
      };

      "niri/window" = {
        max-length = 60;
        separate-outputs = true;
      };

      clock = {
        format = "{:%a %d %b  %H:%M}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      network = {
        format-wifi = "󰖩 {essid}";
        format-ethernet = "󰈀 wired";
        format-disconnected = "󰖪 off";
        tooltip-format = "{ifname} {ipaddr}";
        on-click = "nm-connection-editor";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 muted";
        format-icons.default = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
        on-click = "pavucontrol";
      };

      power-profiles-daemon = {
        format = "{icon}";
        format-icons = {
          performance = "󰓅";
          balanced = "󰾅";
          power-saver = "󰾆";
          default = "󰾅";
        };
      };

      battery = {
        states = {
          warning = 25;
          critical = 10;
        };
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = [
          "󰁺"
          "󰁼"
          "󰁾"
          "󰂀"
          "󰁹"
        ];
      };

      tray.spacing = 8;
    };

    style = ''
      * {
        font-family: "${font}";
        font-size: 12px;
        border: none;
        min-height: 0;
      }

      window#waybar {
        background: ${c.base00};
        color: ${c.base05};
        border-bottom: 1px solid ${c.base02};
      }

      /* Each module is a chip */
      #workspaces, #window, #clock, #tray, #network,
      #pulseaudio, #power-profiles-daemon, #battery {
        background: ${c.base01};
        border: 1px solid ${c.base02};
        border-radius: 999px;
        padding: 0 12px;
        margin: 4px 0;
      }
      #workspaces { padding: 0 4px; margin-left: 8px; }
      #battery { margin-right: 8px; }
      window#waybar.empty #window { background: transparent; border-color: transparent; }

      #workspaces button {
        color: ${c.base03};
        padding: 0 8px;
        border-radius: 999px;
        font-size: 14px;
      }
      #workspaces button.active {
        color: ${c.base00};
        background: ${c.base0A};
      }

      #clock {
        color: ${c.base0A};
        border-color: ${c.base0A};
        font-weight: bold;
        letter-spacing: 1px;
      }

      #battery.warning { color: ${c.base09}; }
      #battery.critical { color: ${c.base00}; background: ${c.base08}; }
      #network.disconnected, #pulseaudio.muted { color: ${c.base03}; }
    '';
  };
}
