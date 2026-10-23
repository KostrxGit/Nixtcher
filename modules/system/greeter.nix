# Graphical login screen matching the desktop: the wallpaper, Kaer Morhen palette,
# Inter, a clock above the login card. Runs under greetd.
# If it ever fails to start: Ctrl+Alt+F2 gives a text login.
{
  config,
  pkgs,
  settings,
  ...
}:
let
  p = (import ../../theme/palette.nix).dark;
  h = v: "#${v}";
in
{
  services.displayManager.noctalia-greeter = {
    enable = true;
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };
    settings = {
      session.default = "niri";
      user.default = settings.username;

      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
        hide_logo = true;
        password_style = "default";
        corner_radius_scale = 1.5;
        font_family = config.stylix.fonts.sansSerif.name;
        power_buttons_position = "bottom-right";
        scheme_selector_position = "hidden";

        palette = {
          primary = h p.accent;
          on_primary = h p.onAccent;
          secondary = h p.base04;
          on_secondary = h p.base00;
          tertiary = h p.base09;
          on_tertiary = h p.base00;
          error = h p.base08;
          on_error = h p.base00;
          surface = h p.base00;
          on_surface = h p.base05;
          surface_variant = h p.base01;
          on_surface_variant = h p.base04;
          outline = h p.base02;
          shadow = h p.shadow;
          hover = h p.hover;
          on_hover = h p.base05;
        };

        wallpaper = {
          path = "${config.stylix.image}";
          fill_mode = "crop";
        };
      };

      clock = {
        enabled = true;
        position = "above-panel";
        time_format = "{:%H:%M}";
        date_format = "%A, %d %B";
      };

      keyboard = {
        layout = settings.keyboardLayout;
        numlock = true;
      };

      idle.timeout = 300;
    };
  };
}
