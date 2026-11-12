{ lib, pkgs, ... }:
{
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  # No thermald: on this ThinkPad the firmware manages cooling (DYTC), and thermald quits on
  # purpose when it sees that ("Thermald can't run on this platform").

  # Burst power cap. The firmware allows 15 W sustained but 64 W bursts; on all-core work
  # (npm ci, builds) those bursts heat the thin chassis to 100 °C within seconds. This only
  # lowers the short-term limit (PL2), per power profile, and puts it back when the firmware
  # resets it after a profile change. Sustained limits stay as the firmware sets them.
  #   performance 64 W (unchanged) · balanced 45 W · power saver 30 W
  systemd.services.burst-power-limit = {
    description = "Cap CPU burst power per power profile";
    wantedBy = [ "multi-user.target" ];
    after = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "burst-power-limit";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            want() {
              case "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)" in
                performance) echo 64000000 ;;
                low-power) echo 30000000 ;;
                *) echo 45000000 ;;
              esac
            }
            while true; do
              w=$(want)
              for zone in /sys/class/powercap/intel-rapl-mmio:0 /sys/class/powercap/intel-rapl:0; do
                f=$zone/constraint_1_power_limit_uw # short_term
                [ -w "$f" ] && [ "$(cat "$f")" != "$w" ] && { echo "$w" >"$f" 2>/dev/null || true; }
              done
              sleep 5
            done
          '';
        }
      );
    };
  };

  # Stop charging at 80% to protect the battery (ThinkPad ACPI)
  systemd.services.battery-charge-threshold = {
    description = "Set battery charge stop threshold";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold || true'";
    };
  };

  # Let users change the charge limit (`ranger travel` = 100% once, `ranger home` = 80%)
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="BAT0", RUN+="${pkgs.coreutils}/bin/chgrp users /sys%p/charge_control_end_threshold", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/charge_control_end_threshold"
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };
}
