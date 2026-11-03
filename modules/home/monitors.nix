# Monitors: any number of screens, arranged so their edges always touch (niri only lets the
# mouse and windows cross between screens that touch).
#
#   - New set of screens: external ones go side by side above the laptop screen, centred.
#   - Rearrange by dragging: `monitors` opens wdisplays. Whatever you set there is saved
#     automatically for that exact set of screens and restored next time they're plugged in.
#   - `monitors reset` forgets the saved layout for the current screens.
#
# Screens are recognised by make + model + serial, so a dock or another port doesn't matter.
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
      store=''${XDG_CONFIG_HOME:-$HOME/.config}/monitor-layouts.json
      [ -s "$store" ] || echo '{}' >"$store"

      # Active screens: [{id, conn, x, y, w, h}], sorted by connector name
      screens() {
        jq -c '[to_entries[] | select(.value.logical != null) | {
            id: ([.value.make, .value.model, (.value.serial // .key)] | join(" ")),
            conn: .key,
            x: .value.logical.x, y: .value.logical.y,
            w: .value.logical.width, h: .value.logical.height
          }] | sort_by(.conn)' <<<"$1"
      }
      setKey() { jq -r '[.[].id] | sort | join(" + ")' <<<"$1"; }
      positions() { jq -c 'map({key: .id, value: {x, y}}) | from_entries' <<<"$1"; }

      # Default: externals in a row above the laptop screen, centred on it, bottoms touching it
      defaultLayout() {
        jq -c '
          (map(select(.conn | startswith("eDP"))) | first) as $lap
          | map(select(.conn | startswith("eDP") | not)) as $ext
          | ($ext | map(.w) | add // 0) as $total
          | (if $lap then $lap.x + (($lap.w - $total) / 2 | floor) else 0 end) as $x0
          | (if $lap then {($lap.id): {x: $lap.x, y: $lap.y}} else {} end)
            + (reduce range(0; $ext | length) as $i ({x: $x0, out: {}};
                .out[$ext[$i].id] = {x: .x, y: (if $lap then $lap.y - $ext[$i].h else 0 end)}
                | .x += $ext[$i].w)
              | .out)' <<<"$1"
      }

      apply() { # $1 = screens, $2 = {id: {x, y}}
        jq -r --argjson pos "$2" '.[] | select($pos[.id]) | "\(.conn) \($pos[.id].x) \($pos[.id].y)"' <<<"$1" |
          while read -r conn x y; do
            niri msg output "$conn" position set -- "$x" "$y" >/dev/null 2>&1 || true
          done
      }

      lastSet=""
      expected=""
      while true; do
        if j=$(niri msg --json outputs 2>/dev/null); then
          s=$(screens "$j")
          key=$(setKey "$s")
          if [ "$(jq length <<<"$s")" -le 1 ]; then
            lastSet=$key
            expected=""
          elif [ "$key" != "$lastSet" ]; then
            # a different set of screens: restore its saved layout, or build the default
            saved=$(jq -c --arg k "$key" '.[$k] // empty' "$store")
            want=''${saved:-$(defaultLayout "$s")}
            apply "$s" "$want"
            sleep 1
            apply "$(screens "$(niri msg --json outputs)")" "$want" # again, in case a move overlapped midway
            sleep 1
            expected=$(positions "$(screens "$(niri msg --json outputs)")")
            lastSet=$key
          else
            # same screens: if someone moved them (wdisplays, niri msg), remember that
            now=$(positions "$s")
            if [ -n "$expected" ] && [ "$now" != "$expected" ]; then
              tmp=$(mktemp)
              jq --arg k "$key" --argjson p "$now" '.[$k] = $p' "$store" >"$tmp" && mv "$tmp" "$store"
              expected=$now
            fi
          fi
        fi
        sleep 2
      done
    '';
  };

  # monitors          open the arranger (drag screens; the layout is saved by itself)
  # monitors reset    forget the saved layout for the screens connected now
  # monitors list     show connected screens and where they are
  monitors = pkgs.writeShellApplication {
    name = "monitors";
    runtimeInputs = with pkgs; [
      niri
      jq
      coreutils
      systemd
      wdisplays
    ];
    text = ''
      store=''${XDG_CONFIG_HOME:-$HOME/.config}/monitor-layouts.json
      case "''${1:-arrange}" in
        arrange) exec wdisplays ;;
        list)
          niri msg --json outputs | jq -r 'to_entries[] | select(.value.logical != null)
            | "\(.key)\t\(.value.make) \(.value.model)\t\(.value.logical.width)x\(.value.logical.height) at \(.value.logical.x),\(.value.logical.y)"'
          ;;
        reset)
          key=$(niri msg --json outputs | jq -r '[to_entries[] | select(.value.logical != null)
            | [.value.make, .value.model, (.value.serial // .key)] | join(" ")] | sort | join(" + ")')
          if [ -s "$store" ]; then
            tmp=$(mktemp)
            jq --arg k "$key" 'del(.[$k])' "$store" >"$tmp" && mv "$tmp" "$store"
          fi
          systemctl --user restart monitor-layout
          echo "Forgot the layout for: $key"
          ;;
        *) echo "usage: monitors [list|reset]   (no argument: open the arranger)"; exit 1 ;;
      esac
    '';
  };
in
{
  home.packages = [
    monitorLayout
    monitors
    pkgs.wdisplays
  ];

  systemd.user.services.monitor-layout = {
    Unit = {
      Description = "Keep all screens touching; remember layouts per set of screens";
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
