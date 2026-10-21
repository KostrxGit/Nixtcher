{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    # Extensions below are pinned by Nix; you can still try others from the
    # marketplace — add the ones you keep to this list.
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        anthropic.claude-code
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
        bradlc.vscode-tailwindcss
        ms-python.python
        charliermarsh.ruff
        rust-lang.rust-analyzer
        jnoortheen.nix-ide
        mkhl.direnv
        eamodio.gitlens
        usernamehw.errorlens
      ];
      userSettings = {
        "editor.formatOnSave" = true;
        "editor.codeActionsOnSave" = {
          "source.organizeImports" = "explicit";
          "source.removeUnusedImports" = "explicit";
          "source.fixAll.eslint" = "explicit";
        };
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "boundary";
        "window.titleBarStyle" = "custom";
        "window.menuBarVisibility" = "toggle";
        "workbench.startupEditor" = "none";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "git.autofetch" = true;
        "git.enableSmartCommit" = false;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "[python]"."editor.defaultFormatter" = "charliermarsh.ruff";
        "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";
        "extensions.autoUpdate" = false;
      };
    };
  };

  # Secondary editor to learn at your own pace (LazyVim setup in the guide)
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };
  stylix.targets.neovim.enable = false; # LazyVim brings its own colourscheme

  home.packages = with pkgs; [
    nil # Nix language server
    nixfmt
    gcc # tree-sitter parsers in Neovim
  ];
}
