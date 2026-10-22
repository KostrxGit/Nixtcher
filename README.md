# Withcer NixOS

NixOS config for a ThinkPad X1 Yoga Gen 7: Niri, casino theme (light/dark), per-project dev shells, Claude Code agent workflow.

Install from scratch: follow the install guide doc. Edit `settings.nix` first.

## Daily commands

| Command | Does |
| --- | --- |
| `rebuild` | Apply changes in this repo (`nh os switch`) |
| `update` | Update all inputs and apply |
| `theme light` / `theme dark` / `theme toggle` | Switch palette (also Mod+Shift+T) |
| `newproj <work\|personal> <name> [node\|expo\|python\|rust]` | New repo with a dev shell |
| `proj` | Fuzzy-jump to a repo |
| `manager`, `task …` | Agent workflow, see `~/code/personal/claude-agents` |

## Layout

```
flake.nix            inputs and outputs
settings.nix         username, disk, emails — edit before install
hosts/x1-yoga/       disk layout (disko), hardware config
modules/system/      boot, network, power, desktop, docker
modules/home/        niri, waybar, fuzzel, mako, hyprlock, ghostty, zsh, git, editors, scripts
theme/               palette.nix (colours) + Stylix and the light specialisation
templates/           dev-shell flakes for new projects
```

Colours live only in `theme/palette.nix`.
