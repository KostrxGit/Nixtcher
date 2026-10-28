# The only file you must edit before installing.
{
  username = "";
  fullName = "";
  hostname = "x1";

  # Disk to wipe and install on. Check with `lsblk` in the installer.
  disk = "/dev/nvme0n1";

  timeZone = "";
  keyboardLayout = ""; # Polish programmer layout

  # Weather on the lock screen and in the control centre
  city = "";

  git = {
    personalEmail = "example@gmail.com";
    workEmail = "CHANGE-ME@work.example"; # used for repos under ~/code/work
  };
}
