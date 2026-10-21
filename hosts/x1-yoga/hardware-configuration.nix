# PLACEHOLDER — replaced during install by:
#   nixos-generate-config --no-filesystems --show-hardware-config > hosts/x1-yoga/hardware-configuration.nix
# (File systems come from disko.nix, so this only holds kernel modules and CPU settings.)
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
}
