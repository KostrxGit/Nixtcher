{ pkgs, ... }:
let
  # Kaer Morhen boot screen: the wolf medallion and Vesna by her campfire, disk password
  # in a glass field (theme/plymouth). If it ever fails to show, press Esc for the text prompt.
  kaerMorhenPlymouth = pkgs.runCommand "kaer-morhen-plymouth" { } ''
    dir=$out/share/plymouth/themes/kaer-morhen
    mkdir -p $dir
    cp ${../../theme/plymouth}/* $dir/
    cat >$dir/kaer-morhen.plymouth <<EOF
    [Plymouth Theme]
    Name=Kaer Morhen
    Description=Wolf medallion and a campfire
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/kaer-morhen.script
    EOF
  '';
in
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

    # Graphical boot + LUKS passphrase prompt
    plymouth = {
      enable = true;
      theme = "kaer-morhen";
      themePackages = [ kaerMorhenPlymouth ];
    };
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

  stylix.targets.plymouth.enable = false; # replaced by the Kaer Morhen theme above
}
