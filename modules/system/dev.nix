{ pkgs, ... }:
{
  # Rootless Docker: `docker` and `docker compose` work without sudo
  virtualisation.docker = {
    enable = false; # no root daemon
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # adb for Expo / React Native on a USB-connected phone
  environment.systemPackages = [ pkgs.android-tools ];

  # Claude Code plugins, installed and enabled for every session (managed settings, so
  # nothing writes into ~/.claude/settings.json, which is a link into the claude-agents repo).
  # Language servers: Claude sees the editor's diagnostics (type errors, unused or missing
  # imports) right after each edit. The binaries come from modules/home/claude.nix.
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    enabledPlugins = {
      "typescript-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
    };
  };

  # Expo dev server and Metro on the LAN
  networking.firewall.allowedTCPPorts = [
    8081
    19000
    19001
  ];
}
