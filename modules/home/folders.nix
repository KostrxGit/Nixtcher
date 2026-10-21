# ~/code/{work,personal} with an area CLAUDE.md each (created once, then yours to edit)
{ lib, ... }:
let
  workMd = ./area-claude/work.md;
  personalMd = ./area-claude/personal.md;
in
{
  home.activation.codeFolders = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/code/work" "$HOME/code/personal" "$HOME/notes" "$HOME/Pictures/Screenshots"
    [ -e "$HOME/code/work/CLAUDE.md" ] || run install -m 644 ${workMd} "$HOME/code/work/CLAUDE.md"
    [ -e "$HOME/code/personal/CLAUDE.md" ] || run install -m 644 ${personalMd} "$HOME/code/personal/CLAUDE.md"
  '';
}
