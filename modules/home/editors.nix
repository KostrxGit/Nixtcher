# VS Code: your settings, keybindings and extensions from the old laptop,
# plus Nix/direnv support. Theme: GitHub Dark (Stylix's theme is off for VS Code).
# Settings changed in the UI aren't kept: edit this file and `rebuild`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  code = "${config.programs.vscode.package}/bin/code";

  # Not packaged in nixpkgs: installed from the marketplace on rebuild
  marketplace = [
    "burkeholland.simple-react-snippets"
    "clinyong.vscode-css-modules"
    "msjsdiag.vscode-react-native"
    "thekalinga.bootstrap4-vscode"
  ];
in
{
  stylix.targets.vscode.enable = false; # keep your own VS Code theme

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    # Extensions below are pinned by Nix; you can still try others from the
    # marketplace — add the ones you keep to this file.
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # from your old setup
        anthropic.claude-code
        esbenp.prettier-vscode
        dbaeumer.vscode-eslint
        aaron-bond.better-comments
        ecmel.vscode-html-css
        formulahendry.auto-rename-tag
        pranaygp.vscode-css-peek
        mechatroner.rainbow-csv
        rangav.vscode-thunder-client
        tomoki1207.pdf
        vscode-icons-team.vscode-icons
        github.github-vscode-theme
        ms-python.python
        ms-python.vscode-pylance
        ms-python.debugpy
        ms-python.black-formatter
        ms-python.vscode-python-envs
        ms-toolsai.jupyter
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-cell-tags
        ms-toolsai.vscode-jupyter-slideshow
        rust-lang.rust-analyzer
        ms-azuretools.vscode-docker
        ms-azuretools.vscode-containers
        # added for this system
        jnoortheen.nix-ide
        mkhl.direnv
        charliermarsh.ruff
        usernamehw.errorlens
      ];

      keybindings = [
        {
          key = "ctrl+u";
          command = "claude-vscode.editor.openLast";
          when = "!config.claudeCode.useTerminal";
        }
      ];

      userSettings = {
        # from your old setup
        "workbench.colorTheme" = "GitHub Dark";
        "workbench.iconTheme" = "vscode-icons";
        "vsicons.dontShowNewVersionMessage" = true;
        "workbench.sideBar.location" = "right";
        "editor.formatOnSave" = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll.eslint" = "explicit";
        };
        "editor.minimap.enabled" = false;
        "javascript.updateImportsOnFileMove.enabled" = "always";
        "typescript.updateImportsOnFileMove.enabled" = "always";
        "[javascript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        "[javascriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        "[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        "[typescriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        "[css]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        "[json]"."editor.defaultFormatter" = "vscode.json-language-features";
        "claudeCode.preferredLocation" = "panel";
        "claudeCode.hideOnboarding" = true;
        "chat.viewSessions.orientation" = "stacked";
        "chat.extensionUnification.enabled" = false;
        "explorer.confirmPasteNative" = false;
        "remote.autoForwardPortsSource" = "hybrid";
        "telemetry.feedback.enabled" = false;
        "workbench.enableExperiments" = false;

        # added for this system
        "editor.fontFamily" = "'${config.stylix.fonts.monospace.name}', monospace";
        "editor.fontSize" = 14;
        "terminal.integrated.fontFamily" = "'${config.stylix.fonts.monospace.name}'";
        "window.titleBarStyle" = "custom";
        "window.menuBarVisibility" = "toggle";
        "workbench.startupEditor" = "none";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "git.enableSmartCommit" = false;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nil";
        "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
        "[python]"."editor.defaultFormatter" = "charliermarsh.ruff";
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";
        "extensions.autoUpdate" = false;
      };
    };
  };

  home.activation.vscodeMarketplace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    installed=$(${code} --list-extensions 2>/dev/null || true)
    for ext in ${lib.concatStringsSep " " marketplace}; do
      if ! grep -qix "$ext" <<<"$installed"; then
        run ${code} --install-extension "$ext" >/dev/null 2>&1 || echo "VS Code: could not install $ext (offline?)"
      fi
    done
  '';

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
