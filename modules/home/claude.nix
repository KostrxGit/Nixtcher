# Claude Code itself is installed with the official native installer (auto-updates,
# runs thanks to nix-ld). This module only links the agent kit into ~/.claude.
# The kit is a separate git repo: ~/code/personal/claude-agents
{ config, pkgs, ... }:
let
  # PostToolUse hook (wired in the kit's settings.json): format + lint every file Claude edits
  lintHook = pkgs.writeShellApplication {
    name = "claude-lint-hook";
    runtimeInputs = with pkgs; [
      jq
      git
      coreutils
      gnugrep
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ]; # no errexit: linters exit non-zero when they find something, that's expected
    text = builtins.replaceStrings [ "@RUFF@" ] [ "${pkgs.ruff}/bin/ruff" ] (
      builtins.readFile ./claude-lint-hook.sh
    );
  };
  kit = "${config.home.homeDirectory}/code/personal/claude-agents";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.sessionPath = [ "$HOME/.local/bin" ]; # native installer puts `claude` here

  # Language servers for the Claude Code LSP plugins (enabled system-wide in
  # modules/system/dev.nix): after every edit Claude sees type errors and unused imports.
  home.packages = with pkgs; [
    lintHook
    typescript-language-server # has its own TypeScript 5 fallback; repos use their own
    pyright
    rust-analyzer
  ];

  home.file = {
    ".claude/agents".source = link "${kit}/agents";
    ".claude/settings.json".source = link "${kit}/settings.json";
    ".claude/CLAUDE.md".source = link "${kit}/CLAUDE.md";
  };

  programs.zsh.shellAliases.manager = "claude --agent manager";
}
