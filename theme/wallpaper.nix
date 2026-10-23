# Wallpaper. Uses theme/wallpapers/witcher.jpg (both variants) once it is in the repo
# and `git add`-ed; dark.png / light.png override per variant. Otherwise a plain
# gradient from wallpaper-svg.nix is rendered in the palette's colours.
{
  pkgs,
  colors,
  variant, # "dark" or "light"
}:
let
  perVariant = ./wallpapers + "/${variant}.png";
  shared = ./wallpapers/witcher.jpg;
  svg = pkgs.writeText "fallback-wallpaper-${variant}.svg" (
    import ./wallpaper-svg.nix {
      c = colors;
      inherit variant;
    }
  );
in
if builtins.pathExists perVariant then
  perVariant
else if builtins.pathExists shared then
  shared
else
  pkgs.runCommand "fallback-wallpaper-${variant}.png" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    rsvg-convert -w 3840 -h 2400 ${svg} -o $out
  ''
