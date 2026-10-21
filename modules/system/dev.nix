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

  # Expo dev server and Metro on the LAN
  networking.firewall.allowedTCPPorts = [
    8081
    19000
    19001
  ];
}
