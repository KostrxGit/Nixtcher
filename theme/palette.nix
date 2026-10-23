# Colours — the only place they are defined. Picked from the wallpaper
# (Kaer Morhen painting): frost and ice from the snow, sky and mountain blues,
# slate shadows, moss and lichen from the grass, orange flowers, ochre stone.
#
#   base00-03  backgrounds (darkest → lighter), 04-07 foregrounds
#   base08-0F  terminal/syntax: red, orange, yellow, green, cyan, blue, magenta, brown
#   accent / onAccent / glassEdge / shadow  UI colours for Niri, Noctalia, fallback wallpaper
{
  dark = {
    scheme = "Kaer Morhen Dusk";
    author = "Konstanty";
    base00 = "161C26"; # background (night slate, from the shadows)
    base01 = "1F2733"; # surfaces, panels
    base02 = "2E3A4C"; # selection, outlines
    base03 = "5F6E86"; # muted text (mountain shade)
    base04 = "9AB0C9"; # secondary text (ice)
    base05 = "DEE5EE"; # main text (frost)
    base06 = "EAF0F6";
    base07 = "F6F9FC"; # snow
    base08 = "C8663A"; # red-orange (flowers)
    base09 = "D9894A"; # orange
    base0A = "C9C46A"; # yellow (lichen)
    base0B = "8DAF5E"; # green (moss)
    base0C = "6FA5A0"; # cyan (stream)
    base0D = "7FA6D9"; # blue (sky)
    base0E = "C48AA6"; # magenta (heather)
    base0F = "A88A4E"; # brown (tower stone)

    accent = "8DB3E2"; # sky blue — focus, active, buttons
    onAccent = "161C26";
    hover = "2B374A";
    glassEdge = "DEE5EE";
    shadow = "0A0F16";
  };

  light = {
    scheme = "Kaer Morhen Snow";
    author = "Konstanty";
    base00 = "EEF3F8"; # background (frost)
    base01 = "E1E9F2"; # surfaces
    base02 = "C7D4E3"; # selection, outlines (ice)
    base03 = "6E7E97"; # muted text
    base04 = "526B92"; # secondary text (mountain blue)
    base05 = "222932"; # main text (night slate)
    base06 = "182029";
    base07 = "10161D";
    base08 = "B4502A";
    base09 = "AF5F1E"; # orange flowers
    base0A = "8C8A2E";
    base0B = "577A33"; # moss
    base0C = "3F726D";
    base0D = "3D5C86"; # deep blue
    base0E = "9A5A78";
    base0F = "7E6334"; # stone

    accent = "4B6FA5"; # mountain blue
    onAccent = "FFFFFF";
    hover = "D3DEEA";
    glassEdge = "FFFFFF";
    shadow = "1B2433";
  };
}
