{ inputs, settings, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-yoga-7th-gen
    inputs.home-manager.nixosModules.home-manager
    inputs.stylix.nixosModules.stylix

    (import ./disko.nix { disk = settings.disk; })
    ./hardware-configuration.nix

    ../../modules/system
    ../../theme
  ];

  networking.hostName = settings.hostname;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs settings; };
    users.${settings.username} = import ../../modules/home;
  };

  # Set once at install, never change.
  system.stateVersion = "26.05";
}
