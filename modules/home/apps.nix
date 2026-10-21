{ pkgs, ... }:
{
  home.packages = with pkgs; [
    google-chrome # Microsoft 365, Teams, Outlook as Chrome web apps
    nautilus
    pavucontrol
    networkmanagerapplet # nm-connection-editor
    loupe # image viewer
    papers # PDF viewer
    gnome-calculator
  ];

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
