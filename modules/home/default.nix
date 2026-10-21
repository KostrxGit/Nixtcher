{ settings, ... }:
{
  imports = [
    ./niri.nix
    ./bar.nix
    ./launcher.nix
    ./notifications.nix
    ./lock.nix
    ./terminal.nix
    ./shell.nix
    ./git.nix
    ./editors.nix
    ./apps.nix
    ./scripts.nix
    ./folders.nix
    ./claude.nix
  ];

  home = {
    username = settings.username;
    homeDirectory = "/home/${settings.username}";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  # Restart changed user services (waybar, wallpaper) on every switch,
  # so a theme change shows up immediately.
  systemd.user.startServices = "sd-switch";
}
