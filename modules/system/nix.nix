{ settings, ... }:
{
  nixpkgs.config.allowUnfree = true; # Chrome, VS Code, Claude Code extension

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        settings.username
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # Lets unpatched binaries run (Claude Code native installer, Python wheels, VS Code servers)
  programs.nix-ld.enable = true;

  # `nh os switch` = nicer nixos-rebuild with a diff of what changed
  programs.nh = {
    enable = true;
    flake = "/home/${settings.username}/nixos";
  };
}
