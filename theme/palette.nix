# Casino palette — the only place colours are defined.
# Base16 roles: 00-03 backgrounds, 04-07 foregrounds, 08-0F accents.
# Hues the reference screenshots don't have (green, cyan, blue, magenta)
# are pulled toward the palette: olive-gold, sand, brown-grey, muted rose.
{
  dark = {
    scheme = "Casino Dark";
    author = "Konstanty";
    base00 = "0A0908"; # background (near-black)
    base01 = "16130F"; # surfaces, bar, panels
    base02 = "2A241C"; # selection
    base03 = "5E5446"; # muted text, comments
    base04 = "8C7A5A"; # secondary text (tan-gold)
    base05 = "C8B898"; # main text (warm sand)
    base06 = "E0D3B5";
    base07 = "F2E9D5";
    base08 = "B8322A"; # card red — errors, critical
    base09 = "C9803A"; # orange
    base0A = "C9A04A"; # gold — accent, active border
    base0B = "9A9455"; # "green" → olive-gold
    base0C = "9C8F78"; # "cyan" → sand
    base0D = "8A7F6E"; # "blue" → brown-grey
    base0E = "A0605A"; # "magenta" → muted rose
    base0F = "7A5A3A"; # brown
  };

  light = {
    scheme = "Casino Light";
    author = "Konstanty";
    base00 = "E8E4DC"; # background (cream)
    base01 = "EFE6CC"; # surfaces (parchment)
    base02 = "DCD3BE"; # selection
    base03 = "9A9080"; # muted text
    base04 = "6B5E4E";
    base05 = "3D3229"; # main text (dark brown)
    base06 = "2A221B";
    base07 = "18130F";
    base08 = "C0392B"; # card red
    base09 = "B86A1E";
    base0A = "E0A84A"; # amber — accent, active border
    base0B = "7A7438";
    base0C = "7A6E5C";
    base0D = "6B6052";
    base0E = "8E4A44";
    base0F = "6B4A2E";
  };
}
