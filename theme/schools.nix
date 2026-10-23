# Witcher schools: accent colours layered over the Kaer Morhen palette (palette.nix).
# Switch with `school wolf|cat|griffin|bear` or by scrolling on the bar medallion.
# Wolf is the base palette itself; it changes Noctalia (bar, panels, widgets, lock screen),
# the medallion and its hum. Terminal and window borders keep the Wolf colours.
{
  wolf = {
    dark = { };
    light = { };
  };
  cat = {
    dark = {
      accent = "D4A35A"; # amber eyes
      hover = "3A3426";
    };
    light = {
      accent = "9A6B1F";
      hover = "E8DFC9";
    };
  };
  griffin = {
    dark = {
      accent = "79C3D1"; # glacier teal
      hover = "23394A";
    };
    light = {
      accent = "2F7F8C";
      hover = "D0E6EA";
    };
  };
  bear = {
    dark = {
      accent = "C98B5E"; # bronze
      hover = "3D3029";
    };
    light = {
      accent = "8F5A33";
      hover = "E8D7C9";
    };
  };
}
