{ settings, ... }:
{
  imports = [
    ./niri.nix
    ./noctalia.nix
    ./terminal.nix
    ./shell.nix
    ./git.nix
    ./editors.nix
    ./apps.nix
    ./scripts.nix
    ./folders.nix
    ./claude.nix
    ./cheatsheet.nix
    ./codex.nix
    ./monitors.nix
    ./witcher.nix
    ./kaer-morhen.nix
    ./sigurd.nix
  ];

  home = {
    username = settings.username;
    homeDirectory = "/home/${settings.username}";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;

  # Restart changed user services (Noctalia, monitor layout) on every switch,
  # so a theme change shows up immediately.
  systemd.user.startServices = "sd-switch";
}
