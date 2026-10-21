{
  networking.networkmanager.enable = true;

  # Tailscale: run `sudo tailscale up` once after install
  services.tailscale.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };
}
