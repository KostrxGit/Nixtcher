{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  font = config.stylix.fonts.monospace.name;
in
{
  # Base colours from Stylix; layout and the label here
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 0;
      };
      input-field = {
        size = "300, 50";
        position = "0, -60";
        halign = "center";
        valign = "center";
        outline_thickness = 2;
        rounding = 25;
        placeholder_text = "Place your bet";
        fade_on_empty = false;
      };
      label = [
        {
          text = "TABLE CLOSED";
          color = "rgb(${c.base0A})";
          font_size = 28;
          font_family = font;
          position = "0, 60";
          halign = "center";
          valign = "center";
        }
        {
          text = "cmd[update:30000] date +'%H:%M'";
          color = "rgb(${c.base05})";
          font_size = 64;
          font_family = font;
          position = "0, 180";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  # Lock after 10 min idle, screen off at 15, suspend at 30
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 600;
        command = "${pkgs.systemd}/bin/loginctl lock-session";
      }
      {
        timeout = 900;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
      {
        timeout = 1800;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
    events = {
      lock = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
      before-sleep = "${pkgs.systemd}/bin/loginctl lock-session";
    };
  };
}
