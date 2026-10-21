# Claude Code itself is installed with the official native installer (auto-updates,
# runs thanks to nix-ld). This module only links the agent kit into ~/.claude.
# The kit is a separate git repo: ~/code/personal/claude-agents
{ config, ... }:
let
  kit = "${config.home.homeDirectory}/code/personal/claude-agents";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.sessionPath = [ "$HOME/.local/bin" ]; # native installer puts `claude` here

  home.file = {
    ".claude/agents".source = link "${kit}/agents";
    ".claude/settings.json".source = link "${kit}/settings.json";
    ".claude/CLAUDE.md".source = link "${kit}/CLAUDE.md";
  };

  programs.zsh.shellAliases.manager = "claude --agent manager";
}
