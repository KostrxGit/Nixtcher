{ config, pkgs, ... }:
let
  # note "text"   adds a line to today's journal note: ~/Notes/Journal/2026-11-12.md
  # note          asks for the line (Super+Shift+N opens this in a small window)
  # Folio shows ~/Notes: every folder is a notebook, every .md file a note.
  note = pkgs.writeShellApplication {
    name = "note";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      dir=$HOME/Notes/Journal
      file=$dir/$(date +%F).md
      if [ $# -gt 0 ]; then
        line="$*"
      else
        printf '\n  \033[1m✎  Quick note\033[0m  \033[2m(Enter saves to today'"'"'s journal · empty Enter cancels)\033[0m\n\n  '
        IFS= read -r -e line || exit 0
      fi
      [ -n "''${line// /}" ] || exit 0
      mkdir -p "$dir"
      [ -s "$file" ] || printf '# Journal, %s\n\n' "$(date '+%A %-d %B %Y')" >"$file"
      printf -- '- %s  %s\n' "$(date +%H:%M)" "$line" >>"$file"
      [ $# -gt 0 ] && echo "Added to $file"
      exit 0
    '';
  };
in
{
  home.packages = with pkgs; [
    google-chrome # Microsoft 365, Teams, Outlook as Chrome web apps
    nautilus
    pavucontrol
    networkmanagerapplet # nm-connection-editor
    loupe # image viewer
    papers # PDF viewer
    gnome-calculator
    folio # notes: Markdown notebooks in ~/Notes
    note
  ];

  # Folio keeps its notebooks in ~/Notes (the default is a hidden Flatpak-style folder)
  dconf.settings."com/toolstack/Folio" = {
    notes-dir = "${config.home.homeDirectory}/Notes";
    trash-dir = "${config.home.homeDirectory}/Notes/.trash";
  };

  # KDE Connect daemon + tray icon (pair the phone from the tray or `kdeconnect-app`)
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "application/pdf" = "org.gnome.Papers.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = null;
    music = null;
    publicShare = null;
    templates = null;
    videos = null;
  };
}
