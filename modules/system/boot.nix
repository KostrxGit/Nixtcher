{ pkgs, ... }:
{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # boot menu keeps the last 10 generations
        editor = false;
      };
      efi.canTouchEfiVariables = true;
      timeout = 2;
    };

    kernelPackages = pkgs.linuxPackages_latest;

    # Graphical boot + LUKS passphrase prompt (themed by Stylix)
    plymouth.enable = true;
    initrd.systemd.enable = true;
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "rd.udev.log_level=3"
    ];
  };

  # Compressed RAM swap in addition to the 8 GB swap file
  zramSwap.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };
}
