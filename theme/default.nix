# Stylix applies the palette to everything it supports.
# Dark is the default system; light is a specialisation switched with `theme light`.
{ lib, pkgs, ... }:
let
  palette = import ./palette.nix;
in
{
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = palette.dark;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        terminal = 11;
        applications = 11;
        desktop = 11;
        popups = 11;
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Amber";
      size = 24;
    };
    targets.gtksourceview.enable = false;
    targets.nixos-icons.enable = false;
  };

  # Marker file the `theme` script reads to know the current variant
  environment.etc."theme-variant".text = "dark";

  specialisation.light.configuration = {
    stylix.polarity = lib.mkForce "light";
    stylix.base16Scheme = lib.mkForce palette.light;
    environment.etc."theme-variant".text = lib.mkForce "light";
  };
}
