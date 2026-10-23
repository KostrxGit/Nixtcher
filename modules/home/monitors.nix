# External monitor: whatever you plug in is placed directly above the laptop
# screen, centred. Runs in the background and reacts within ~2 seconds.
# Lid closed with a monitor attached turns the laptop screen off (niri.nix).
{ pkgs, ... }:
let
  monitorLayout = pkgs.writeShellApplication {
    name = "monitor-layout";
    runtimeInputs = with pkgs; [
      niri
      jq
      coreutils
    ];
    text = ''
      internal=eDP-1
      last=""
      while true; do
        if j=$(niri msg --json outputs 2>/dev/null); then
          ext=$(jq -r --arg i "$internal" \
            'to_entries[] | select(.key != $i and .value.logical != null) | .key' <<<"$j" | head -n1)
          if [ -n "$ext" ] && [ "$(jq -r --arg i "$internal" '.[$i].logical != null' <<<"$j")" = true ]; then
            read -r iw ix iy < <(jq -r --arg o "$internal" '.[$o].logical | "\(.width) \(.x) \(.y)"' <<<"$j")
            read -r ew eh < <(jq -r --arg o "$ext" '.[$o].logical | "\(.width) \(.height)"' <<<"$j")
            key="$ext:$ew:$eh:$iw:$ix:$iy"
            if [ "$key" != "$last" ]; then
              x=$((ix + (iw - ew) / 2))
              y=$((iy - eh))
              niri msg output "$ext" position set -- "$x" "$y" && last=$key
            fi
          elif [ -z "$ext" ]; then
            last=""
          fi
        fi
        sleep 2
      done
    '';
  };
in
{
  home.packages = [ monitorLayout ];

  systemd.user.services.monitor-layout = {
    Unit = {
      Description = "Place external monitors above the laptop screen";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${monitorLayout}/bin/monitor-layout";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
