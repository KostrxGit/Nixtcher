# Small commands: theme, newproj, task (agent workflow), plus the `proj` jump.
{ lib, pkgs, ... }:
let
  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = with pkgs; [
      coreutils
      procps
      systemd
    ];
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
      # Ghostty keeps running in the background: tell it to reload config and colours
      systemctl --user kill --kill-whom=main -s USR2 app-com.mitchellh.ghostty.service 2>/dev/null || true
      pkill -USR2 -f '\.ghostty-wrapped' 2>/dev/null || true
      echo "Theme: $target"
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

  # Agent workflow. Cards live in docs/tasks/<ID>-*.md, written by the manager:
  #   TIN-1234-01-login-form.md   Linear issue TIN-1234, card 01 → branch TIN-1234-task-01
  #   003-login.md                older cards without an issue  → branch task-003
  # Every window working on a card is titled "<ID> · coder|review|terminal" and gets the
  # card's colour (theme/cards.nix): a thick border from niri and a dark tint in Ghostty.
  cards = import ../../theme/cards.nix;
  task = pkgs.writeShellApplication {
    name = "task";
    runtimeInputs = with pkgs; [
      coreutils
      git
      findutils
      gnugrep
      gnused
      gawk
      lazygit
    ];
    text = ''
      usage() {
        cat <<EOF
      task list               cards and agent worktrees in this repo
      task start ID           coding agent for card ID, in its own worktree + window
      task review ID          reviewer for card ID's worktree
      task term ID            terminal in card ID's worktree
      task code ID            VS Code on card ID's worktree
      task diff ID            lazygit in card ID's worktree
      task commands ID        the commit, merge (--no-ff) and clean-up commands for card ID
      task clean ID           remove card ID's worktree after you merged it (card → done)

      ID is the card's id: TIN-1234-01, or 003 for older cards ("task-001" works too).
      EOF
      }

      root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Not in a git repo"; exit 1; }
      cd "$root"

      TINTS=(${lib.escapeShellArgs (map (c: c.tint) cards)})

      isLinear() { [[ $1 =~ ^[A-Z][A-Z0-9]*-[0-9]+-[0-9]+$ ]]; }
      issueOf() { if isLinear "$1"; then echo "''${1%-*}"; fi; }
      numberOf() { echo "''${1##*-}"; }
      branchOf() { if isLinear "$1"; then echo "$(issueOf "$1")-task-$(numberOf "$1")"; else echo "task-$1"; fi; }
      wt() { if isLinear "$1"; then echo "$root/.claude/worktrees/$1"; else echo "$root/.claude/worktrees/task-$1"; fi; }
      card() {
        local f
        f=$(find docs/tasks -maxdepth 1 -name "$1-*.md" 2>/dev/null | sort | head -n1)
        [ -n "$f" ] || { echo "No card docs/tasks/$1-*.md" >&2; exit 1; }
        echo "$root/$f"
      }
      # front matter: read a field / set a field (added before the closing --- if missing)
      field() { awk -v k="$2" 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} index($0, k":")==1 {sub("^[^:]*:[ \t]*", ""); print; exit}' "$1"; }
      setField() {
        local tmp
        head -n1 "$1" | grep -qx -- '---' || return 0
        tmp=$(mktemp)
        awk -v k="$2" -v v="$3" '
          NR==1 {print; fm=1; next}
          fm && $0=="---" { if (!done) print k": "v; fm=0; print; next }
          fm && index($0, k":")==1 { print k": "v; done=1; next }
          {print}' "$1" >"$tmp" && cat "$tmp" >"$1"
        rm -f "$tmp"
      }
      title() { sed -n 's/^#[[:space:]]\+//p' "$1" | head -n1 | sed -E 's/^[A-Z0-9-]+[[:space:]]*(—|–|:|-)[[:space:]]*//'; }
      # Ghostty window look for a card: title + the card's colour as a dark tint
      look() {
        local n idx
        n=$(numberOf "$1"); n=$((10#''${n:-1})); idx=$(( (n > 0 ? n - 1 : 0) % ''${#TINTS[@]} ))
        printf '%s\n' "--title=$1 · $2" "--theme=night" "--background=''${TINTS[$idx]}" "--background-opacity=0.85"
      }
      needWorktree() { [ -d "$1" ] || { echo "No worktree $1 (run: task start $2)"; exit 1; }; }

      cmd=''${1:-}
      n=''${2:-}; n=''${n#task-}
      case "$cmd" in
        list)
          echo "Cards:"
          for f in docs/tasks/*.md; do
            [ -e "$f" ] || continue
            printf '  %-46s %-18s %s\n' "$(basename "$f")" "$(field "$f" status)" "$(field "$f" base)"
          done
          echo; echo "Worktrees:"; git worktree list
          ;;
        start)
          [ -n "$n" ] || { usage; exit 1; }
          f=$(card "$n"); d=$(wt "$n"); b=$(branchOf "$n")
          # The worktree branches off what you have checked out now. Running start again
          # reuses it, e.g. after a review asked for changes.
          if [ ! -d "$d" ]; then
            base=$(git branch --show-current); base=''${base:-HEAD}
            exclude=$(git rev-parse --git-path info/exclude)
            git check-ignore -q "$d" || grep -qxF '.claude/worktrees/' "$exclude" 2>/dev/null ||
              echo '.claude/worktrees/' >>"$exclude"
            if git show-ref --verify --quiet "refs/heads/$b"; then
              git worktree add "$d" "$b"
              echo "Worktree $d on the existing branch $b."
            else
              git worktree add -b "$b" "$d" "$base"
              setField "$f" base "$base"
              echo "Worktree $d on new branch $b (from $base)."
            fi
          fi
          mapfile -t lookArgs < <(look "$n" coder)
          # Cards are usually uncommitted, so the agent reads them from the main checkout.
          # `--` ends the options: --add-dir takes several values and would eat the prompt.
          ghostty --working-directory="$d" "''${lookArgs[@]}" -e claude --agent coder -n "$n · coder" \
            --add-dir "$root/docs/tasks" \
            -- "Implement the task card $f (card $n). Read it first and follow it exactly." &
          disown
          echo "Coding agent for $n opened in a new window."
          ;;
        review)
          [ -n "$n" ] || { usage; exit 1; }
          f=$(card "$n"); d=$(wt "$n"); needWorktree "$d" "$n"
          base=$(field "$f" base)
          mapfile -t lookArgs < <(look "$n" review)
          ghostty --working-directory="$d" "''${lookArgs[@]}" -e claude --agent reviewer -n "$n · review" \
            --add-dir "$root/docs/tasks" \
            -- "Review card $n: the changes in this worktree ($d, branch $(branchOf "$n"), started from ''${base:-the branch it was started from}) against the card $f. If you approve, finish with the output of: task commands $n" &
          disown
          echo "Reviewer for $n opened in a new window."
          ;;
        term)
          [ -n "$n" ] || { usage; exit 1; }
          d=$(wt "$n"); needWorktree "$d" "$n"
          mapfile -t lookArgs < <(look "$n" terminal)
          ghostty --working-directory="$d" "''${lookArgs[@]}" &
          disown
          ;;
        code)
          [ -n "$n" ] || { usage; exit 1; }
          d=$(wt "$n"); needWorktree "$d" "$n"
          code -n "$d" >/dev/null 2>&1 &
          disown
          ;;
        diff)
          [ -n "$n" ] || { usage; exit 1; }
          d=$(wt "$n"); needWorktree "$d" "$n"
          lazygit -p "$d"
          ;;
        commands)
          [ -n "$n" ] || { usage; exit 1; }
          f=$(card "$n"); d=$(wt "$n"); b=$(branchOf "$n")
          base=$(field "$f" base); base=''${base:-$(git branch --show-current)}
          type=$(field "$f" type); type=''${type:-feat}
          issue=$(field "$f" issue); issue=''${issue:-$(issueOf "$n")}
          t=$(title "$f")
          msg="''${issue:+($issue)}$type: $t"
          cat <<EOF
      # 1. Commit the work, in the card's worktree
      cd $d
      git add -A
      git commit -m "$msg"

      # 2. Merge it into $base (--no-ff keeps one merge commit per card)
      cd $root
      git switch $base
      git merge --no-ff $b -m "Merge $b: $t"
      git push

      # 3. Clean up
      task clean $n
      git branch -d $b
      EOF
          ;;
        clean)
          [ -n "$n" ] || { usage; exit 1; }
          d=$(wt "$n")
          git worktree remove "$d" && echo "Removed $d (branch $(branchOf "$n") kept; git branch -d it once merged)"
          if f=$(card "$n" 2>/dev/null); then setField "$f" status "done"; fi
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
          | fzf --prompt='❯ project  ' --height=40% --reverse) && cd "$d"
    }
  '';
}
