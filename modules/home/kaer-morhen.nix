# Kaer Morhen: the Witcher extras around Noctalia.
#   - wolf pup in the bar, trembling medallion, contract board (Noctalia plugin in
#     theme/witcher-plugin, packaged here with the paths it needs)
#   - original sounds: notification chime (sound theme), medallion hum, blade on unlock,
#     potion brewed / spoiled
#   - wallpaper tinted for dawn, day, dusk and night by real sunrise/sunset
#   - `witcher <event>` command, Claude Code hook and idle nap for the pup
#   - Vesna's focus timer, Witcher schools, morning brief, the Forge (Docker), Ranger mode
{
  config,
  lib,
  pkgs,
  settings,
  ...
}:
let
  noctalia = config.programs.noctalia.package;
  home = config.home.homeDirectory;
  src = ../../theme/witcher-plugin;

  # Wallpapers you can switch between (`wall`, Super+Alt+W). The first one is the default
  # (theme/wallpapers/witcher.jpg, or the generated gradient). Add a picture: drop it into
  # theme/wallpapers/, add a line here, `git add`, `rebuild`.
  #   tint = false   for pictures that are already dark: no extra dawn/dusk/night tint
  wallpaperList = [
    {
      id = "witcher";
      title = "Default";
      image = config.stylix.image;
    }
    {
      id = "keep";
      title = "Kaer Morhen";
      image = ../../theme/wallpapers/keep.jpg;
    }
    {
      id = "storm";
      title = "Keep in the storm";
      image = ../../theme/wallpapers/storm.jpg;
      tint = false;
    }
    {
      id = "novigrad";
      title = "Novigrad at sunset";
      image = ../../theme/wallpapers/novigrad.jpg;
    }
  ];
  # the default is always there; the others only once their file is in the repo
  availableWallpapers = builtins.filter (
    w: w.id == "witcher" || builtins.pathExists w.image
  ) wallpaperList;

  # Time-of-day variants of each wallpaper, chosen by real sunrise/sunset. Every variant is
  # cropped to the panel's exact size (3840x2400) at build time, so switching doesn't
  # make the shell decode and rescale a big picture.
  tint =
    id: name: image: args:
    pkgs.runCommand "kaer-morhen-${id}-${name}.jpg" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick ${image} -resize 3840x2400^ -gravity center -extent 3840x2400 ${args} -quality 92 jpg:$out
    '';
  variants =
    w:
    let
      day = "${tint w.id "day" w.image ""}";
    in
    if w.tint or true then
      {
        inherit day;
        dawn = "${tint w.id "dawn" w.image "-modulate 100,90 -fill '#E9B8C8' -colorize 13%"}";
        dusk = "${tint w.id "dusk" w.image "-modulate 94,110 -fill '#E8925A' -colorize 20%"}";
        night = "${tint w.id "night" w.image "-modulate 60,70 -fill '#121C33' -colorize 32%"}";
      }
    else
      {
        inherit day;
        dawn = day;
        dusk = day;
        night = day;
      };
  wallpapers = builtins.listToAttrs (
    map (w: {
      name = w.id;
      value = variants w // {
        inherit (w) title;
      };
    }) availableWallpapers
  );
  wallpaperOrder = map (w: w.id) availableWallpapers;

  # Reads every task card in the code folders and prints one tab-separated line per card, so
  # the shell plugin never has to open hundreds of files itself (each plugin call gets only
  # 25 ms of CPU). Columns: repo, repo path, card file, card ID, issue (from the name), card
  # number, worktree open (0/1), modified (epoch s), status, issue (front matter), base,
  # title, ticked boxes, all boxes, "changes requested" section (0/1), issue title.
  cardsScript = pkgs.writeShellApplication {
    name = "kaer-morhen-cards";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
    ];
    text = ''
      shopt -s nullglob
      files=() wts=()
      for root in "$@"; do
        [ -d "$root" ] || continue
        files+=("$root"/*/docs/tasks/*.md)
        wts+=("$root"/*/.claude/worktrees/*/)
      done
      [ ''${#files[@]} -gt 0 ] || exit 0
      WTS=$(printf '%s\n' "''${wts[@]%/}") MTS=$(stat -c '%Y %n' "''${files[@]}") awk '
        function start(f) {
          name = f; sub(/.*\//, "", name)
          repoPath = f; sub(/\/docs\/tasks\/[^\/]*$/, "", repoPath)
          repo = repoPath; sub(/.*\//, "", repo)
          ok = 1
          if (name ~ /^[A-Z][A-Z0-9]*-[0-9]+-[0-9][0-9]?[0-9]?-.*\.md$/) {
            match(name, /^[A-Z][A-Z0-9]*-[0-9]+-/); issue = substr(name, 1, RLENGTH - 1)
            rest = substr(name, RLENGTH + 1); match(rest, /^[0-9]+/); no = substr(rest, 1, RLENGTH)
            id = issue "-" no; wt = repoPath "/.claude/worktrees/" id
          } else if (name ~ /^[0-9]+-.*\.md$/) {
            match(name, /^[0-9]+/); no = substr(name, 1, RLENGTH); issue = ""
            id = no; wt = repoPath "/.claude/worktrees/task-" id
          } else ok = 0
          cur = f; fm = 0; status = ""; iss = ""; ititle = ""; base = ""; title = ""; ticked = 0; total = 0; changes = 0
        }
        function flush() {
          if (cur != "" && ok)
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%s\n", repo, repoPath, cur, id, issue, no,
              (wt in WT), MT[cur], status, iss, base, title, ticked, total, changes, ititle
          cur = ""
        }
        BEGIN {
          n = split(ENVIRON["WTS"], w, "\n"); for (i = 1; i <= n; i++) if (w[i] != "") WT[w[i]] = 1
          n = split(ENVIRON["MTS"], l, "\n"); for (i = 1; i <= n; i++) { p = index(l[i], " "); if (p) MT[substr(l[i], p + 1)] = substr(l[i], 1, p - 1) }
        }
        FNR == 1 { flush(); start(FILENAME) }
        !ok { next }
        FNR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---" { fm = 0; next }
        fm && match($0, /^[A-Za-z_-]+:/) {
          k = substr($0, 1, RLENGTH - 1); v = substr($0, RLENGTH + 1)
          gsub(/^[ \t]+|[ \t\r]+$/, "", v)
          gsub(/\t/, " ", v)
          if (k == "status") status = v; else if (k == "issue") iss = v; else if (k == "base") base = v
          else if (k == "issue-title") ititle = v
          next
        }
        !fm && title == "" && /^#[ \t]+/ { title = $0; sub(/^#[ \t]+/, "", title); gsub(/[\t\r]/, " ", title) }
        /^[ \t]*[-*][ \t]+\[[ xX]\]/ { total++; if ($0 ~ /\[[xX]\]/) ticked++ }
        /^## Changes requested/ { changes = 1 }
        END { flush() }
      ' "''${files[@]}"
    '';
  };

  pluginConfig = pkgs.writeText "kaer-morhen-config.json" (
    builtins.toJSON {
      noctalia = lib.getExe noctalia;
      dbusMonitor = "${pkgs.dbus}/bin/dbus-monitor";
      git = lib.getExe pkgs.git;
      docker = "${pkgs.docker}/bin/docker";
      petName = "Vesna";
      userName = settings.fullName or "";
      city = builtins.head (lib.splitString "," (settings.city or "Kaer Morhen"));
      focusMinutes = 25;
      breakMinutes = 5;
      longBreakMinutes = 15;
      battery = "/sys/class/power_supply/BAT0";
      healthWarnBelow = 80;
      palettes = {
        wolf = "witcher";
        cat = "km-cat";
        griffin = "km-griffin";
        bear = "km-bear";
      };
      codeDirs = [
        "${home}/code/work"
        "${home}/code/personal"
      ];
      daynight = true;
      # from settings.nix if set there, otherwise Sønderborg
      latitude = settings.latitude or 54.91;
      longitude = settings.longitude or 9.79;
      inherit wallpapers wallpaperOrder;
      titleFont = config.stylix.fonts.serif.name;
      # Encounters: merchant challenges, monster contracts, travellers, badges.
      # `encounters off` pauses them; change the numbers here and rebuild.
      encounters = {
        enabled = true;
        perDay = 5; # at most this many a day, spread out at random
        from = 9; # only between 9:00 ...
        to = 22; # ... and 22:00, never during focus, when idle or locked
        sigurd = true; # Sigurd trots in to announce them
      };
      sigurd = "${config.home.profileDirectory}/bin/sigurd";
      bin = "${config.home.profileDirectory}/bin"; # ghostty, guide, cheatsheet for the launcher
      cards = lib.getExe cardsScript; # reads the task cards for the ledger and the board
    }
  );

  # Noctalia "path" source: a folder that contains plugin folders
  plugins = pkgs.runCommand "kaer-morhen-plugins" { } ''
    mkdir -p $out/kaer-morhen
    cd ${src}
    cp -r plugin.toml *.luau lib translations assets $out/kaer-morhen/
    cp ${pluginConfig} $out/kaer-morhen/config.json
  '';

  # Send an event to the plugin: witcher agent "text" | build-ok | build-fail | test-ok | ...
  witcher = pkgs.writeShellApplication {
    name = "witcher";
    runtimeInputs = [ noctalia ];
    text = ''
      [ $# -ge 1 ] || { echo "usage: witcher <event> [text]"; exit 1; }
      exec noctalia msg plugin konstanty/kaer-morhen:events all "$1" "''${2:-}"
    '';
  };

  # Claude Code hook: "agent" when an agent waits for you, "agent-done" when it finishes
  claudeHook = pkgs.writeShellApplication {
    name = "witcher-claude-hook";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      witcher
    ];
    text = ''
      input=$(cat)
      repo=$(basename "$(jq -r '.cwd // "."' <<<"$input")")
      msg=$(jq -r '.message // empty' <<<"$input")
      witcher "''${1:-agent}" "$repo: ''${msg:-finished}" >/dev/null 2>&1 || true
    '';
  };

  # school wolf|cat|griffin|bear   (no name: next school)
  school = pkgs.writeShellApplication {
    name = "school";
    runtimeInputs = [ witcher ];
    text = ''
      case "''${1:-}" in
        "" | wolf | cat | griffin | bear) exec witcher school "''${1:-}" ;;
        *) echo "usage: school [wolf|cat|griffin|bear]"; exit 1 ;;
      esac
    '';
  };

  # focus: start / stop a 25-minute focus session (Vesna meditates)
  focus = pkgs.writeShellApplication {
    name = "focus";
    runtimeInputs = [ witcher ];
    text = ''exec witcher focus'';
  };

  # brief: open the morning brief
  brief = pkgs.writeShellApplication {
    name = "brief";
    runtimeInputs = [ noctalia ];
    text = ''exec noctalia msg panel-toggle konstanty/kaer-morhen:brief'';
  };

  # Lore subtitles in the launcher: each app's own .desktop file with a Witcher GenericName
  # (the grey line under the name). Same file name, so it takes the original's place.
  loreApps = [
    {
      pkg = config.programs.ghostty.package;
      match = "com.mitchellh.ghostty";
      lore = "Grimoire · terminal";
    }
    {
      pkg = pkgs.google-chrome;
      match = "google-chrome";
      lore = "Raven post · web browser";
    }
    {
      pkg = config.programs.vscode.package;
      match = "code";
      lore = "Alchemy table · code editor";
    }
    {
      pkg = pkgs.nautilus;
      match = "org.gnome.Nautilus";
      lore = "Saddlebags · files";
    }
    {
      pkg = config.services.kdeconnect.package;
      match = "org.kde.kdeconnect.app";
      lore = "Messenger ravens · your phone";
    }
    {
      pkg = pkgs.loupe;
      match = "org.gnome.Loupe";
      lore = "Painter's gallery · images";
    }
    {
      pkg = pkgs.papers;
      match = "org.gnome.Papers";
      lore = "Scrolls and tomes · PDF";
    }
    {
      pkg = pkgs.gnome-calculator;
      match = "org.gnome.Calculator";
      lore = "Merchant's abacus · calculator";
    }
    {
      pkg = pkgs.pavucontrol;
      match = "*pavucontrol";
      lore = "Bard's lute · volume mixer";
    }
  ];
  appLore = pkgs.runCommand "kaer-morhen-app-lore" { } (
    ''
      mkdir -p $out
    ''
    + lib.concatMapStrings (a: ''
      for f in ${a.pkg}/share/applications/${a.match}.desktop; do
        [ -e "$f" ] || { echo "kaer-morhen: no ${a.match}.desktop in ${a.pkg}, skipped" >&2; continue; }
        # drop the old GenericName lines, add ours right after the [Desktop Entry] header
        awk -v lore=${lib.escapeShellArg a.lore} '
          /^GenericName/ { next }
          { print }
          !done && $0 == "[Desktop Entry]" { print "GenericName=" lore; done = 1 }
        ' "$f" > "$out/$(basename "$f")"
      done
    '') loreApps
  );

  # wall [next|prev|list|<name>]   switch wallpaper (keeps the day/night tint)
  wall = pkgs.writeShellApplication {
    name = "wall";
    runtimeInputs = [ witcher ];
    text = ''
      case "''${1:-next}" in
        list)
          ${lib.concatMapStringsSep "\n" (w: "echo '  ${w.id}  ${w.title}'") availableWallpapers}
          ;;
        next | prev ${lib.concatMapStrings (id: " | ${id}") wallpaperOrder}) exec witcher wallpaper "''${1:-next}" ;;
        *) echo "usage: wall [next|prev|list|${lib.concatStringsSep "|" wallpaperOrder}]"; exit 1 ;;
      esac
    '';
  };

  # bestiary: purse, challenge, contracts, badges and discoveries
  bestiary = pkgs.writeShellApplication {
    name = "bestiary";
    runtimeInputs = [ witcher ];
    text = ''exec witcher bestiary'';
  };

  # encounters [on|off|now]   pause, resume, or summon one right away (no argument: toggle)
  encounters = pkgs.writeShellApplication {
    name = "encounters";
    runtimeInputs = [ witcher ];
    text = ''
      case "''${1:-}" in
        "" | on | off | now) exec witcher encounters "''${1:-}" ;;
        *) echo "usage: encounters [on|off|now]"; exit 1 ;;
      esac
    '';
  };

  # ranger [on|off]   power saver + dimmer screen (also a control-centre tile)
  # ranger travel     charge to 100% once, for a long day away from a socket
  # ranger home       back to the 80% charge limit that protects the battery
  ranger = pkgs.writeShellApplication {
    name = "ranger";
    runtimeInputs = [
      witcher
      pkgs.coreutils
    ];
    text = ''
      limit=/sys/class/power_supply/BAT0/charge_control_end_threshold
      case "''${1:-toggle}" in
        on | off) exec witcher ranger "$1" ;;
        toggle) exec witcher ranger "" ;;
        travel) echo 100 >"$limit" && echo "Charging to 100% (until 'ranger home' or the next boot)." ;;
        home) echo 80 >"$limit" && echo "Charge limit back to 80%." ;;
        *) echo "usage: ranger [on|off|travel|home]"; exit 1 ;;
      esac
    '';
  };
in
{
  xdg.dataFile."applications" = {
    source = appLore;
    recursive = true;
  };

  home.packages = [
    witcher
    claudeHook
    school
    focus
    brief
    ranger
    bestiary
    encounters
    wall
  ];

  # Notification chime (other sounds fall back to the freedesktop theme)
  home.file.".local/share/sounds/kaer-morhen/index.theme".text = ''
    [Sound Theme]
    Name=Kaer Morhen
    Inherits=freedesktop
    Directories=stereo

    [stereo]
    OutputProfile=stereo
  '';
  home.file.".local/share/sounds/kaer-morhen/stereo/message-new-instant.wav".source =
    ../../theme/witcher-plugin/assets/sounds/chime.wav;

  programs.noctalia.settings = {
    plugins = {
      enabled = [ "konstanty/kaer-morhen" ];
      source = [
        {
          name = "kaer-morhen";
          kind = "path";
          location = "${plugins}";
          enabled = true;
        }
      ];
    };

    audio.sound_theme = "kaer-morhen";

    # Vesna's portrait in the launcher and on the lock screen
    shell.avatar_path = "${src}/assets/avatar.png";

    # The power menu (Super+Shift+E, or the button in the launcher), keys 1-5
    shell.session.actions = [
      {
        action = "lock";
        label = "Rest by the fire";
        glyph = "flame";
        shortcut = "1";
      }
      {
        action = "logout";
        label = "Leave the keep";
        glyph = "door-exit";
        shortcut = "2";
      }
      {
        action = "lock_and_suspend";
        label = "Meditate";
        glyph = "moon";
        shortcut = "3";
      }
      {
        action = "reboot";
        label = "Return to Kaer Morhen";
        glyph = "refresh";
        shortcut = "4";
      }
      {
        action = "shutdown";
        label = "Blow out the candles";
        glyph = "candle";
        variant = "destructive";
        shortcut = "5";
      }
    ];

    widget = {
      pup.type = "konstanty/kaer-morhen:pup";
      medallion.type = "konstanty/kaer-morhen:medallion";
    };

    # Control centre tiles (max 6): Ranger replaces Caffeine
    control_center.shortcuts = map (type: { inherit type; }) [
      "wifi"
      "bluetooth"
      "konstanty/kaer-morhen:ranger"
      "nightlight"
      "notification"
      "power_profile"
    ];

    # Blade on unlock, "welcome back", and the morning brief on the first unlock of the day
    hooks = {
      session_locked = "${lib.getExe witcher} locked";
      session_unlocked = "${lib.getExe witcher} unlocked";
    };

    # The pup naps after 2 minutes without input and wakes when you're back
    idle.behavior.pup-nap = {
      timeout = 120;
      action = "command";
      command = "${lib.getExe witcher} idle";
      resume_command = "${lib.getExe witcher} active";
      enabled = true;
    };
  };
}
