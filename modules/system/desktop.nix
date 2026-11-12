{ pkgs, ... }:
{
  imports = [ ./greeter.nix ];

  programs.niri.enable = true;

  # Login screen: Noctalia greeter (see greeter.nix)
  services.greetd.enable = true;

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  security.polkit.enable = true;
  xdg.sounds.enable = true; # sound theme for Noctalia

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

  # KDE Connect with an Android phone: notifications, files, clipboard, remote input
  # (opens ports 1714-1764 on the firewall; the daemon runs per user, see modules/home/apps.nix)
  programs.kdeconnect.enable = true;
  programs.dconf.enable = true; # settings store for GTK apps (Folio's notes folder)

  # btop reads the Intel GPU's load through the kernel's perf counters, which needs
  # CAP_PERFMON. This wrapper (/run/wrappers/bin/btop, first on PATH) gives it just that.
  security.wrappers.btop = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon+ep";
    source = "${pkgs.btop}/bin/btop";
  };

  services.gvfs.enable = true; # trash, mounts in Nautilus
  services.udisks2.enable = true;
}
