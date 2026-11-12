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
      jq
      procps
      util-linux
      libnotify
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

      # The main checkout, also when run from inside a card's worktree. The Stop hook passes the
      # agent's directory as JSON on stdin (task auto).
      cmd=''${1:-}
      if [ "$cmd" = auto ]; then
        hookInput=$(cat 2>/dev/null || true)
        here=$(jq -r '.cwd // empty' <<<"$hookInput" 2>/dev/null || true); here=''${here:-$PWD}
        case "$here" in */.claude/worktrees/*) ;; *) exit 0 ;; esac # not a card's agent
        cd "$here" 2>/dev/null || exit 0
      fi
      common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "Not in a git repo"; exit 1; }
      root=$(dirname "$common")
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

      # ── launching agents (Opus, auto mode: safe actions run, risky ones are blocked or asked;
      #    the deny list in ~/.claude/settings.json always wins) ──
      MAX_FIX_ROUNDS=2
      launchCoder() { # $1 card ID, $2 fix round (0 = first run)
        local f d title prompt
        f=$(card "$1"); d=$(wt "$1")
        if [ "''${2:-0}" -gt 0 ]; then
          title="coder (fix $2)"
          prompt="Card $1: the reviewer asked for changes (fix round $2 of $MAX_FIX_ROUNDS). Read the latest '## Review' section of the card $f and fix exactly those points, then run the acceptance checks, update '## Result' and set status: review."
        else
          title="coder"
          prompt="Implement the task card $f (card $1). Read it first and follow it exactly."
        fi
        mapfile -t lookArgs < <(look "$1" "$title")
        # Cards are usually uncommitted, so the agent reads them from the main checkout.
        # `--` ends the options: --add-dir takes several values and would eat the prompt.
        setsid env KM_ROLE=coder ghostty --working-directory="$d" "''${lookArgs[@]}" -e \
          claude --agent coder --model opus --permission-mode auto -n "$1 · $title" \
          --add-dir "$root/docs/tasks" -- "$prompt" >/dev/null 2>&1 </dev/null &
        disown
      }
      launchReviewer() { # $1 card ID
        local f d base
        f=$(card "$1"); d=$(wt "$1"); base=$(field "$f" base)
        mapfile -t lookArgs < <(look "$1" review)
        setsid env KM_ROLE=reviewer ghostty --working-directory="$d" "''${lookArgs[@]}" -e \
          claude --agent reviewer --model opus --permission-mode auto -n "$1 · review" \
          --add-dir "$root/docs/tasks" \
          -- "Review card $1: the changes in this worktree ($d, branch $(branchOf "$1"), started from ''${base:-the branch it was started from}) against the card $f. If you approve, finish with the output of: task commands $1" \
          >/dev/null 2>&1 </dev/null &
        disown
      }

      # ── the automatic loop (task auto, run by the Stop hook after every agent turn) ──
      # Per worktree it remembers "<fix rounds used> <last status handled>", so each step runs once.
      stateFile() { echo "$(git -C "$1" rev-parse --absolute-git-dir)/kaer-morhen-auto"; }
      # End the agent session that ran this hook; its window closes with it. Only an ancestor
      # process that is a claude session named "<card ID> · <role>" (as launched above) qualifies.
      closeSelf() { # $1 card ID, $2 role title prefix (coder / review)
        local pid=$$ cmdline _
        for _ in 1 2 3 4 5 6; do
          pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
          [ -n "$pid" ] && [ "$pid" -gt 1 ] || return 0
          cmdline=$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null || true)
          if grep -q 'claude' <<<"$cmdline" && grep -qxF -- "-n" <<<"$cmdline" &&
            grep -qx -- "$1 · $2.*" <<<"$cmdline"; then
            setsid sh -c "sleep 4; kill -TERM $pid" >/dev/null 2>&1 </dev/null &
            return 0
          fi
        done
      }
      tell() { # $1 title, $2 message, $3 witcher event
        notify-send -a "Kaer Morhen" "$1" "$2" >/dev/null 2>&1 || true
        if command -v sigurd >/dev/null; then sigurd say "$1: $2" >/dev/null 2>&1 || true; fi
        if command -v witcher >/dev/null; then witcher "$3" "$1" >/dev/null 2>&1 || true; fi
      }
      autoStep() { # $1 card ID, $2 role of the session that just stopped (coder/reviewer)
        local d f st sf round=0 last=""
        d=$(wt "$1"); [ -d "$d" ] || return 0
        f=$(card "$1" 2>/dev/null) || return 0
        st=$(field "$f" status)
        sf=$(stateFile "$d")
        if [ -f "$sf" ]; then read -r round last <"$sf" || true; fi
        round=''${round:-0}
        [ "$st" != "$last" ] || return 0 # already handled
        case "$2:$st" in
          coder:review)
            echo "$round review" >"$sf"
            launchReviewer "$1"
            closeSelf "$1" coder
            ;;
          reviewer:changes-requested)
            if [ "$round" -lt "$MAX_FIX_ROUNDS" ]; then
              round=$((round + 1))
              echo "$round changes-requested" >"$sf"
              launchCoder "$1" "$round"
              closeSelf "$1" review
            else
              echo "$round changes-requested" >"$sf"
              tell "$1 needs you" "Still not right after $MAX_FIX_ROUNDS fixes. Read the review; task start $1 runs one more round." agent
            fi
            ;;
          reviewer:approved)
            echo "$round approved" >"$sf"
            tell "$1 approved" "Ready for your commit and merge (task commands $1)." agent-done
            ;;
        esac
      }

      n=''${2:-}; n=''${n#task-}
      # the card whose worktree the hook ran in: .claude/worktrees/TIN-1234-01 or task-003
      hereId=""
      if [ "$cmd" = auto ]; then hereId=''${here#*/.claude/worktrees/}; hereId=''${hereId%%/*}; hereId=''${hereId#task-}; fi
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
          # reuses it, e.g. after a review asked for changes (counts as one more fix round).
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
          round=0
          sf=$(stateFile "$d")
          if [ -f "$sf" ]; then read -r round _ <"$sf" || true; fi
          if [ "$(field "$f" status)" = "changes-requested" ]; then
            round=$((''${round:-0} + 1)) # you asked for another round
            echo "$round manual" >"$sf"
          fi
          launchCoder "$n" "''${round:-0}"
          echo "Coding agent for $n opened in a new window. The review starts by itself when it's done."
          ;;
        review)
          [ -n "$n" ] || { usage; exit 1; }
          d=$(wt "$n"); needWorktree "$d" "$n"
          launchReviewer "$n"
          echo "Reviewer for $n opened in a new window."
          ;;
        auto)
          n=''${hereId:-}
          [ -n "$n" ] && [ -n "''${KM_ROLE:-}" ] || exit 0 # only sessions started by task
          autoStep "$n" "$KM_ROLE"
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
