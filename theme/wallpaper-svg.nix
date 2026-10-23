# Fallback wallpaper (used until theme/wallpapers/witcher.jpg exists):
# a cold slate gradient with soft mist and a fine grain. 3840×2400.
{
  c,
  variant,
}:
let
  dark = variant == "dark";
  top = if dark then "#1f2533" else "#f6f8fb";
  bottom = if dark then "#0d1016" else "#d4dbe5";
  mist = if dark then "0.10" else "0.35";
in
''
  <svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2400" viewBox="0 0 3840 2400">
    <defs>
      <linearGradient id="bg" x1="0" y1="0" x2="0.3" y2="1">
        <stop offset="0" stop-color="${top}"/>
        <stop offset="1" stop-color="${bottom}"/>
      </linearGradient>
      <radialGradient id="mist" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="#${c.base07}" stop-opacity="${mist}"/>
        <stop offset="1" stop-color="#${c.base07}" stop-opacity="0"/>
      </radialGradient>
      <radialGradient id="ember" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="#${c.accent}" stop-opacity="0.08"/>
        <stop offset="1" stop-color="#${c.accent}" stop-opacity="0"/>
      </radialGradient>
      <filter id="grain">
        <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="3" stitchTiles="stitch"/>
        <feColorMatrix type="saturate" values="0"/>
      </filter>
    </defs>
    <rect width="3840" height="2400" fill="url(#bg)"/>
    <ellipse cx="1300" cy="1900" rx="2200" ry="700" fill="url(#mist)"/>
    <ellipse cx="3100" cy="2200" rx="1400" ry="600" fill="url(#ember)"/>
    <rect width="3840" height="2400" filter="url(#grain)" opacity="0.05"/>
  </svg>
''
