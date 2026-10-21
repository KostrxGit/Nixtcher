{ pkgs, settings, ... }:
{
  time.timeZone = settings.timeZone;
  i18n.defaultLocale = "en_US.UTF-8";
  console.useXkbConfig = true;
  services.xserver.xkb.layout = settings.keyboardLayout;

  users.users.${settings.username} = {
    isNormalUser = true;
    description = settings.fullName;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
    unzip
    file
    pciutils
    usbutils
  ];

  # Firmware updates: `fwupdmgr refresh && fwupdmgr update`
  services.fwupd.enable = true;
  hardware.enableRedistributableFirmware = true;

  # Fingerprint reader stays off until you decide to enrol it
  services.fprintd.enable = false;
}
