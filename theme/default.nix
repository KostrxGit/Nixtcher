# Stylix applies the palette to everything it supports.
# Dark is the default system; light is a specialisation switched with `theme light`.
{ lib, pkgs, ... }:
let
  palette = import ./palette.nix;
  # Stylix only wants the base16 colours
  base16 =
    v:
    removeAttrs palette.${v} [
      "accent"
      "onAccent"
      "hover"
      "glassEdge"
      "shadow"
    ];
  wallpaper =
    variant:
    import ./wallpaper.nix {
      inherit pkgs variant;
      colors = palette.${variant};
    };
in
{
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = base16 "dark";
    image = wallpaper "dark";

    fonts = {
      # Clean sans for the interface, an engraved serif for display text (clock, lock)
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.cinzel;
        name = "Cinzel";
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

    opacity = {
      terminal = 0.78; # glass: Niri blurs what shows through
      popups = 0.85;
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    # These targets patch packages, which forces building GTK apps from source
    # instead of downloading them. Not worth it for a text-editor colour scheme.
    targets.gtksourceview.enable = false;
    targets.nixos-icons.enable = false;
  };

  # Marker file the `theme` script reads to know the current variant
  environment.etc."theme-variant".text = "dark";

  specialisation.light.configuration = {
    stylix.polarity = lib.mkForce "light";
    stylix.base16Scheme = lib.mkForce (base16 "light");
    stylix.image = lib.mkForce (wallpaper "light");
    environment.etc."theme-variant".text = lib.mkForce "light";
  };
}
