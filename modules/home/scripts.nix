# Small commands: theme, newproj, task (agent workflow), plus the `proj` jump.
{ pkgs, ... }:
let
  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      current=$(cat /etc/theme-variant 2>/dev/null || echo dark)
      target=''${1:-toggle}
      if [ "$target" = toggle ]; then
        if [ "$current" = dark ]; then target=light; else target=dark; fi
      fi
      case "$target" in
        light) sudo /nix/var/nix/profiles/system/specialisation/light/bin/switch-to-configuration switch ;;
        dark)  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch ;;
        *) echo "usage: theme [light|dark|toggle]"; exit 1 ;;
      esac
      makoctl reload 2>/dev/null || true
      echo "Theme: $target (open terminals keep the old colours until reopened)"
    '';
  };

  newproj = pkgs.writeShellApplication {
    name = "newproj";
    runtimeInputs = with pkgs; [
      coreutils
      git
      direnv
    ];
    text = ''
      if [ $# -lt 2 ]; then
        echo "usage: newproj <work|personal> <name> [node|expo|python|rust]"
        exit 1
      fi
      area=$1 name=$2 tpl=''${3:-}
      case "$area" in work|personal) ;; *) echo "area must be work or personal"; exit 1 ;; esac
      dir="$HOME/code/$area/$name"
      mkdir -p "$dir" && cd "$dir"
      [ -d .git ] || git init -q
      if [ -n "$tpl" ]; then
        nix flake init -t "$HOME/nixos#$tpl"
        git add -A
        direnv allow
      fi
      mkdir -p docs/tasks
      echo "Created $dir — run: cd $dir"
    '';
  };

  # Agent workflow. Cards live in docs/tasks/NNN-*.md (written by the manager).
  task = pkgs.writeShellApplication {
    name = "task";
    runtimeInputs = with pkgs; [
      coreutils
      git
      findutils
      gnugrep
      lazygit
    ];
    text = ''
      usage() {
        cat <<EOF
      task list            cards and agent worktrees in this repo
      task start NNN       open a coding agent for card NNN in its own worktree + window
      task review NNN      open the reviewer on card NNN's worktree
      task diff NNN        lazygit in card NNN's worktree (review, stage, commit yourself)
      task clean NNN       remove card NNN's worktree after you merged it
      EOF
      }

      root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Not in a git repo"; exit 1; }
      cd "$root"

      card() {
        local f
        f=$(find docs/tasks -maxdepth 1 -name "$1-*.md" 2>/dev/null | head -n1)
        [ -n "$f" ] || { echo "No card docs/tasks/$1-*.md"; exit 1; }
        echo "$f"
      }
      wt() { echo "$root/.claude/worktrees/task-$1"; }

      case "''${1:-}" in
        list)
          echo "Cards:"
          for f in docs/tasks/*.md; do
            [ -e "$f" ] || continue
            s=$(grep -m1 '^status:' "$f" | cut -d' ' -f2- || true)
            printf '  %-40s %s\n' "$(basename "$f")" "''${s:-?}"
          done
          echo; echo "Worktrees:"; git worktree list
          ;;
        start)
          n=''${2:?card number}; f="$root/$(card "$n")"
          # Cards are usually uncommitted, so the agent reads them from the main checkout
          ghostty --working-directory="$root" -e claude -w "task-$n" --agent coder -n "task-$n" \
            --add-dir "$root/docs/tasks" \
            "Implement the task card $f. Read it first and follow it exactly." &
          disown
          echo "Coding agent for $f opened in a new window."
          ;;
        review)
          n=''${2:?card number}; f="$root/$(card "$n")"; d=$(wt "$n")
          [ -d "$d" ] || { echo "No worktree $d"; exit 1; }
          ghostty --working-directory="$d" -e claude --agent reviewer -n "review-$n" \
            --add-dir "$root/docs/tasks" \
            "Review the changes in this worktree against the card $f." &
          disown
          ;;
        diff)
          n=''${2:?card number}; d=$(wt "$n")
          lazygit -p "$d"
          ;;
        clean)
          n=''${2:?card number}; d=$(wt "$n")
          git worktree remove "$d" && echo "Removed $d (branch kept; delete it with git branch -d when merged)"
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  home.packages = [
    theme
    newproj
    task
  ];

  # `proj` = fuzzy-jump into any repo; must be a shell function to change directory
  programs.zsh.initContent = ''
    proj() {
      local d
      d=$(fd --type d --max-depth 1 --hidden --exclude .worktrees . ~/code/work ~/code/personal 2>/dev/null \
          | fzf --prompt='♦ Project  ' --height=40% --reverse) && cd "$d"
    }
  '';
}
