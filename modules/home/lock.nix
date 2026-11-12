# Lock screen: medallion-lock (~/dev/medallion-lock, installed by its NixOS module).
#   - `lock`: keybinds (niri.nix), idle (noctalia.nix) and the power menu (kaer-morhen.nix)
#   - swayidle locks before every suspend (lid close, `systemctl suspend`) and on `loginctl lock-session`
#   - Noctalia's own lock screen is off, so its locked/unlocked hooks are sent from here:
#     blade on unlock, "welcome back" and the morning brief (kaer-morhen.nix)
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  medallion-lock = inputs.medallion-lock.packages.${pkgs.stdenv.hostPlatform.system}.default;

  lock = pkgs.writeShellApplication {
    name = "lock";
    runtimeInputs = [
      medallion-lock
      pkgs.util-linux
    ];
    text = ''
      # One locker at a time: keybind, idle and suspend can fire together.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/medallion-lock.flock"
      flock -n 9 || exit 0
      witcher=${config.home.profileDirectory}/bin/witcher
      [ -x "$witcher" ] && { "$witcher" locked & }
      medallion-lock # runs until unlocked
      [ -x "$witcher" ] && "$witcher" unlocked
      exit 0
    '';
  };
in
{
  home.packages = [ lock ];

  services.swayidle = {
    enable = true;
    # Timeouts stay in Noctalia (noctalia.nix); only lock events here.
    # before-sleep waits a second so the lock is up before the screen goes off.
    events = {
      before-sleep = "${lib.getExe lock} & sleep 1";
      lock = "${lib.getExe lock} &";
    };
  };
}
