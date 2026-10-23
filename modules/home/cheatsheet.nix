# Mod+/ or Mod+F1 (or "Cheatsheet" in the launcher): a floating window with the keybinds.
# Edit the two lists below when you change keybinds in niri.nix.
{ pkgs, ... }:
let
  # ANSI colours from the terminal theme, so it reads in both frost and dark
  cheatsheet = pkgs.writeShellApplication {
    name = "cheatsheet";
    text = ''
      E=$'\e'
      GOLD="''${E}[1;94m"
      RED="''${E}[31m"
      KEY="''${E}[1m"
      TXT="''${E}[90m"
      DIM="''${E}[90m"
      R0="''${E}[0m"

      KW=21 DW=31 # key / description column widths
      CW=$((KW + DW))

      pad() { local s=$1 n=$2; printf '%s%*s' "$s" $((n - ''${#s})) ""; }
      cell() {
        local s=$1
        if [ -z "$s" ]; then pad "" "$CW"
        elif [ "''${s:0:1}" = "#" ]; then printf '%s' "$GOLD"; pad "''${s:1}" "$CW"; printf '%s' "$R0"
        else
          printf '%s' "$KEY"; pad "''${s%%|*}" "$KW"
          printf '%s' "$TXT"; pad "''${s#*|}" "$DW"; printf '%s' "$R0"
        fi
      }

      L=(
        "#WINDOWS"
        "Mod+Return|Terminal"
        "Mod+Space|Launcher"
        "Mod+S|Control centre"
        "Mod+Q|Close window"
        "Mod+←/→   H/L|Focus column"
        "Mod+↑/↓   K/J|Focus window in column"
        "Mod+Ctrl+arrows|Move window"
        "Mod+R|Width ⅓ · ½ · ⅔"
        "Mod+F|Maximise column"
        "Mod+Shift+F|Fullscreen"
        "Mod+C|Centre column"
        "Mod+,  /  Mod+.|Stack into / out of column"
        "Mod+W|Tabs in column"
        "Mod+T|Float / tile"
        "Mod+O|Overview"
        "Mod+Shift+W|Move desktop widgets"
        ""
        "#WORKSPACES & SCREENS"
        "Mod+1 … 4|Go to workspace"
        "Mod+U  /  Mod+I|Workspace down / up"
        "Mod+Ctrl+1 … 4|Send window to workspace"
        "Mod+Shift+↑/↓|Focus monitor above / below"
        "Mod+Shift+Ctrl+↑/↓|Send window to monitor"
        "Lid closed|Laptop screen off"
        ""
        "#SHORTCUTS"
        "gs ga gc gp gl|Status, add, commit, push, pull"
        "gd glog gsw|Diff, history, switch branch"
        "dev  b  t  i|Run dev, build, test, install"
        "dcu dcd dcl dps|Compose up, down, logs; ps"
        "pg  /  redis|Start a local database"
      )
      R=(
        "#APPS & SYSTEM"
        "Mod+B|Chrome"
        "Mod+E|Files"
        "Mod+V|Clipboard history"
        "Mod+Shift+T|Light / dark theme"
        "Mod+Shift+G|Terminal frost / dark"
        "Mod+Esc|Lock screen"
        "Print|Screenshot area"
        "Ctrl / Alt+Print|Screen / window"
        "Mod+/|This cheatsheet"
        "Mod+G|Agent guide (codex)"
        "Mod+M|Focus: Vesna meditates"
        "Mod+Shift+B|Morning brief"
        "Mod+Shift+A|Bestiary: crowns, badges"
        "Mod+Alt+W|Next wallpaper (+Shift: back)"
        "Mod+Shift+/|Every keybind"
        "Mod+Shift+S|Shell settings"
        "Mod+Shift+E|Session menu"
        ""
        "#TERMINAL"
        "rebuild|Apply config (brews a potion)"
        "update|Update everything"
        "cleanup  gens|Free space, list versions"
        "nixconf weather myip|Config, forecast, IP"
        "school <name>|Wolf, Cat, Griffin, Bear"
        "ranger [travel]|Save power / charge 100%"
        "encounters [off|now]|Pause / summon one"
        "sigurd visit|Call Sigurd over"
        "wall [list|name]|Switch wallpaper"
        "codework [name]|Jump to a work repo"
        "codepersonal [name]|Jump to a personal repo"
        "newproj|New repo + dev shell"
        "manager|Plan a task with Claude"
        "task start NNN|Run a coding agent"
        "task diff NNN|Review and commit"
        "claude agents|All running agents"
      )

      printf '\n   %sK E Y B I N D S%s\n' "$GOLD" "$R0"
      printf '   %s%s%s\n\n' "$DIM" "$(printf '─%.0s' $(seq 1 $((CW * 2 + 4))))" "$R0"
      n=''${#L[@]}; [ "''${#R[@]}" -gt "$n" ] && n=''${#R[@]}
      for ((i = 0; i < n; i++)); do
        printf '   '; cell "''${L[i]:-}"; printf '    '; cell "''${R[i]:-}"; printf '\n'
      done
      printf '\n   %sMod is the Super key.  %sPress any key to close.%s' "$DIM" "$RED" "$R0"
      read -rsn1
    '';
  };
in
{
  home.packages = [ cheatsheet ];

  xdg.desktopEntries.cheatsheet = {
    name = "Cheatsheet";
    comment = "Keybinds and commands";
    exec = "ghostty --class=dev.cheatsheet --title=Cheatsheet -e cheatsheet";
    icon = "input-keyboard";
    categories = [ "Utility" ];
  };
}
