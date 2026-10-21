{ pkgs, ... }:
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
      rebuild = "nh os switch";
      update = "nh os switch --update";
    };
  };

  # Prompt segments as chips; palette names come from Stylix
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      format = "[](base0a)$directory[](fg:base0a bg:base02)$git_branch$git_status[](fg:base02)$nodejs$python$rust$nix_shell$cmd_duration\n$character";
      directory = {
        style = "bold fg:base00 bg:base0a";
        format = "[ $path ]($style)";
        truncation_length = 3;
      };
      git_branch = {
        style = "fg:base05 bg:base02";
        format = "[ $symbol$branch ]($style)";
        symbol = " ";
      };
      git_status = {
        style = "fg:base08 bg:base02";
        format = "[$all_status$ahead_behind ]($style)";
      };
      nodejs.format = " [ $version](base0b)";
      python.format = " [ $version](base0b)";
      rust.format = " [ $version](base0b)";
      nix_shell.format = " [♣ dev](base0a)";
      cmd_duration.format = " [$duration](base03)";
      character = {
        success_symbol = "[♠](base0a)";
        error_symbol = "[♥](base08)";
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
