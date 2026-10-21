# The only file you must edit before installing.
{
  username = "konstanty";
  fullName = "Konstanty";
  hostname = "x1";

  # Disk to wipe and install on. Check with `lsblk` in the installer.
  disk = "/dev/nvme0n1";

  timeZone = "Europe/Copenhagen";
  keyboardLayout = "pl"; # Polish programmer layout

  git = {
    personalEmail = "github.kostekgalant@gmail.com";
    workEmail = "github.kostekgalant@gmail.com"; # used for repos under ~/code/work
  };
}
