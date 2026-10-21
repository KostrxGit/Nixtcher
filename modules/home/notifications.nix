{ config, lib, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
in
{
  # Colours from Stylix; shape here — rounded "chip" cards, red border when critical
  services.mako = {
    enable = true;
    settings = {
      border-color = lib.mkForce c.base0A; # gold edge
      border-radius = 10;
      border-size = 2;
      padding = "12";
      margin = "12";
      width = 360;
      default-timeout = 6000;
      layer = "overlay";
      "urgency=critical" = {
        border-color = c.base08;
        default-timeout = 0;
      };
    };
  };
}
