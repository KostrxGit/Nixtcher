# Super+G (or "Witcher's Codex" in the launcher): the guide to working with Claude agents,
# rendered in a floating window. Edit codex.md next to this file and rebuild.
{ pkgs, ... }:
let
  guide = pkgs.writeShellApplication {
    name = "guide";
    runtimeInputs = [ pkgs.glow ];
    text = ''
      exec glow --pager --width 96 ${./codex.md}
    '';
  };
in
{
  home.packages = [ guide ];

  xdg.desktopEntries.witchers-codex = {
    name = "Witcher's Codex";
    comment = "How to work with Claude agents";
    exec = "ghostty --class=dev.codex --title=Codex -e guide";
    icon = "accessories-dictionary";
    categories = [ "Utility" ];
  };
}
