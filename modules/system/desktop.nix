{ pkgs, ... }:
{
  programs.niri.enable = true;

  # Text login screen → starts Niri
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --greeting 'The table is open' --cmd niri-session";
      user = "greeter";
    };
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Lock screen needs a PAM entry
  security.pam.services.hyprlock = { };
  security.polkit.enable = true;

  # Touchscreen, pen, touchpad
  services.libinput.enable = true;
  hardware.sensor.iio.enable = true; # accelerometer for optional auto-rotate

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };

  # Chrome, Electron apps and VS Code run natively on Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  services.gvfs.enable = true; # trash, mounts in Nautilus
  services.udisks2.enable = true;
}
