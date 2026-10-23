{
  pkgs,
  lib,
  settings,
  ...
}:
let
  town = builtins.head (lib.splitString "," settings.city);
in
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 50000;
      ignoreAllDups = true;
      share = true;
    };
    shellAliases = {
      ls = "eza --group-directories-first";
      ll = "eza -la --group-directories-first --git";
      tree = "eza --tree --level=2";
      cat = "bat --paging=never";
      lg = "lazygit";
      # jump around
      ".." = "cd ..";
      "..." = "cd ../..";
      code-dir = "cd ~/code";
      cdn = "cd ~/nixos";
      cda = "cd ~/code/personal/claude-agents";

      # git
      gs = "git status -sb";
      ga = "git add";
      gaa = "git add -A";
      gc = "git commit";
      gcm = "git commit -m";
      gp = "git push";
      gl = "git pull";
      gco = "git checkout";
      gsw = "git switch";
      gb = "git branch";
      gd = "git diff";
      gds = "git diff --staged";
      glog = "git log --graph --pretty=format:'%C(blue)%h%C(reset) %s %C(brightblack)· %an, %ar%C(auto)%d%C(reset)' -n 30";

      # docker
      dps = "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'";
      dcu = "docker compose up -d";
      dcd = "docker compose down";
      dcl = "docker compose logs -f --tail=100";
      dcr = "docker compose restart";

      # system
      cleanup = "nh clean all --keep 3";
      gens = "nixos-rebuild list-generations";
      nixconf = "code ~/nixos";
      myip = "curl -s https://ifconfig.me; echo";
      ports = "ss -tlnp";
    };
  };

  # codework / codepersonal (short: w / p):
  #   no name   → fuzzy list of repos in that area, Enter jumps into the one you pick
  #   <name>    → straight into that repo (Tab completes names)
  # `z <part-of-name>` (zoxide) jumps anywhere you've been.
  programs.zsh.initContent = ''
    _codejump() {
      local area=$1 name=$2 d
      if [ -n "$name" ]; then cd ~/code/$area/$name; return; fi
      d=$(fd --type d --max-depth 1 --hidden --exclude .git . ~/code/$area 2>/dev/null \
          | sed "s|^$HOME/code/$area/||; s|/$||" \
          | fzf --prompt="❯ $area  " --height=40% --reverse) && cd ~/code/$area/$d
    }
    codework() { _codejump work "$1" }
    codepersonal() { _codejump personal "$1" }
    w() { _codejump work "$1" }
    p() { _codejump personal "$1" }
    _cw() { _files -W ~/code/work -/ }
    _cp() { _files -W ~/code/personal -/ }
    compdef _cw codework w
    compdef _cp codepersonal p
    hash -d work=~/code/work personal=~/code/personal nixos=~/nixos

    # JS projects: run with whatever package manager the repo uses (from its lockfile)
    _pm() {
      if [ -f pnpm-lock.yaml ]; then echo pnpm
      elif [ -f bun.lock ] || [ -f bun.lockb ]; then echo bun
      elif [ -f yarn.lock ]; then echo yarn
      else echo npm; fi
    }
    dev() { $(_pm) run dev "$@" }
    i() { $(_pm) install "$@" }
    # build and test also tell the pup how it went (hop or droop)
    _react() { local rc=$1; { witcher "$([ "$rc" -eq 0 ] && echo test-ok || echo test-fail)" >/dev/null 2>&1 & } 2>/dev/null; return "$rc" }
    # a job that ran over a minute: Sigurd trots in with the result
    _sigurd() { (( SECONDS - $1 >= 60 )) && { sigurd say "$2" >/dev/null 2>&1 & } 2>/dev/null; return 0 }
    b() { local s=$SECONDS; $(_pm) run build "$@"; local rc=$?; _sigurd $s "Build in ''${PWD:t} $([ $rc -eq 0 ] && echo finished || echo failed) after $(( (SECONDS - s) / 60 )) min."; _react $rc }
    t() { local s=$SECONDS; $(_pm) run test "$@"; local rc=$?; _sigurd $s "Tests in ''${PWD:t} $([ $rc -eq 0 ] && echo passed || echo failed) after $(( (SECONDS - s) / 60 )) min."; _react $rc }

    # rebuild / update brew a potion: success → "<potion> brewed", failure → it spoils
    _brew() {
      local potion=$1; shift
      print -P "%F{12}%B  ⚗  Brewing $potion%b%f"
      print -P "%F{8}      ) (  )%f"
      print -P "%F{8}     (  ) (%f"
      print -P "%F{11}    .-=======-.%f"
      print -P "%F{11}    |  ~ ~ ~  |%f"
      print -P "%F{11}    '._______.'%f"
      echo
      local start=$SECONDS
      if "$@"; then
        witcher build-ok "$potion" >/dev/null 2>&1
        _sigurd $start "The $potion potion is ready! Brewed in $(( (SECONDS - start) / 60 )) min."
        print -P "%F{2}%B  ✔ $potion brewed.%b%f"
      else
        local rc=$?
        witcher build-fail "$potion" >/dev/null 2>&1
        _sigurd $start "Bad news from the alchemist: the $potion potion spoiled."
        print -P "%F{1}%B  ✘ The potion spoiled (exit $rc).%b%f"
        return $rc
      fi
    }
    _potions=(Swallow Thunderbolt "Tawny Owl" Cat "Golden Oriole" Blizzard "Maribor Forest" "White Honey" "Full Moon" "Killer Whale")
    rebuild() { _brew "''${_potions[$(( RANDOM % ''${#_potions} + 1 ))]}" nh os switch "$@" }
    update() { _brew "White Gull" nh os switch --update "$@" }  # the base every potion starts from

    # Current weather for your city (settings.nix → city)
    weather() {
      curl -s "https://wttr.in/$(printf %s "''${1:-${town}}" | jq -sRr @uri)?format=%l:+%c+%t,+%w&m"; echo
    }

    # Local databases in Docker; data survives restarts (named volumes)
    pg() {
      docker start pg >/dev/null 2>&1 || docker run -d --name pg -p 5432:5432 \
        -e POSTGRES_PASSWORD=postgres -v pgdata:/var/lib/postgresql/data postgres:17 >/dev/null
      echo "Postgres: postgres://postgres:postgres@localhost:5432/postgres   (stop: docker stop pg)"
    }
    redis() {
      docker start redis >/dev/null 2>&1 || docker run -d --name redis -p 6379:6379 \
        -v redisdata:/data redis:7 >/dev/null
      echo "Redis: redis://localhost:6379   (stop: docker stop redis)"
    }
  '';

  # Minimal prompt in the terminal's own ANSI colours, so it reads well in frost and dark:
  # accent path (12), secondary-text git branch (8), red changes, green versions
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_status$nodejs$python$rust$nix_shell$cmd_duration\n$character";
      directory = {
        style = "bold bright-blue";
        format = "[$path]($style)";
        truncation_length = 3;
      };
      git_branch = {
        style = "bright-black";
        format = "  [$symbol$branch]($style)";
        symbol = " ";
      };
      git_status = {
        style = "red";
        format = " [$all_status$ahead_behind]($style)";
      };
      nodejs.format = " [ $version](green)";
      python.format = " [ $version](green)";
      rust.format = " [ $version](green)";
      nix_shell.format = " [ dev](blue)";
      cmd_duration.format = " [$duration](bright-black)";
      character = {
        success_symbol = "[❯](bold)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  # Per-project dev shells load on `cd` (flake.nix + .envrc in the repo)
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.btop.enable = true;
  programs.lazygit.enable = true;
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    tldr
    gh
    httpie
    dust
    duf
  ];
}
