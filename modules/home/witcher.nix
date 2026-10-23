# School medallions (theme/icons) for stickers and the fastfetch logo.
# Desktop / lock screen stickers: Noctalia edit mode → add "Sticker" →
# pick an image from ~/.local/share/witcher/icons/.
{ ... }:
{
  home.file.".local/share/witcher/icons".source = ../../theme/icons;

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "kitty-direct"; # PNG sent straight to Ghostty
        source = "${../../theme/icons/wolf.png}";
        width = 22;
        height = 11;
        padding.top = 1;
      };
      display.separator = "  ";
      modules = [
        "title"
        "separator"
        "os"
        "kernel"
        "wm"
        "terminal"
        "cpu"
        "memory"
        "disk"
        "battery"
        "uptime"
      ];
    };
  };
}
