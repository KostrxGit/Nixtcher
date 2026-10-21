# Disk layout: 1 GB EFI + LUKS2-encrypted Btrfs with subvolumes.
# Used by disko during install (wipes the disk!) and for mounts afterwards.
# Standalone use: disko --mode destroy,format,mount --argstr disk /dev/nvme0n1 ./disko.nix
{
  disk ? "/dev/nvme0n1",
  ...
}:
{
  disko.devices.disk.main = {
    type = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # No keyFile/passwordFile: disko asks for the passphrase interactively.
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes =
                let
                  opts = [
                    "compress=zstd"
                    "noatime"
                  ];
                in
                {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = opts;
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = opts;
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = opts;
                  };
                  "/log" = {
                    mountpoint = "/var/log";
                    mountOptions = opts;
                  };
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "8G";
                  };
                };
            };
          };
        };
      };
    };
  };
}
