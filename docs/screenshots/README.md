# Screenshots for the main README

Take these on the laptop, save them here with exactly these names, then uncomment the matching
`<!-- SCREENSHOT ... -->` block in the main README.

Niri saves screenshots to `~/Pictures/Screenshots`: **Print** = area, **Ctrl+Print** = whole screen.
Then: `mv ~/Pictures/Screenshots/<file>.png ~/nixos/docs/screenshots/<name>.png`

| File | What to show | Tip |
|---|---|---|
| `desktop.png` | Whole screen: bar, calendar, vitals, contract board, the Forge, one frosted terminal | Ctrl+Print. Close personal windows first |
| `bar.png` | Just the bar with Vesna in it | Print, drag across the bar |
| `bestiary.png` | The bestiary panel | `bestiary`, then Print around it |
| `lock.png` | Lock screen with clock and campfire | Run `sleep 8; niri msg action screenshot-screen`, then lock with Super+Esc within 8 s. If it comes out black, skip it |
| `brief.png` | Morning brief | `brief`, then Print around it |
| `codex.png` | The Witcher's Codex in its terminal | Super+G, then Print |

Before committing:
- Shrink big shots so the repo stays light: `nix shell nixpkgs#imagemagick -c magick desktop.png -resize 1920x desktop.png`
- Check that nothing private is visible (notifications, repo names, email).
- If your wallpaper is game or fan art you don't own, take the shots on the generated wallpaper,
  or leave it out of the public repo.
