{ ... }:
{
  # Colours and font from Stylix
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      window-padding-x = 12;
      window-padding-y = 10;
      window-decoration = false;
      cursor-style = "bar";
      confirm-close-surface = false;
      copy-on-select = "clipboard";
      shell-integration-features = "no-cursor";
    };
  };
}
