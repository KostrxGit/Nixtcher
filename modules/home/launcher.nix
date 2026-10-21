{ ... }:
{
  # Colours and font come from Stylix
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        prompt = "'♠ Place your bet  '";
        terminal = "ghostty -e";
        width = 40;
        lines = 10;
        horizontal-pad = 20;
        vertical-pad = 14;
        inner-pad = 8;
      };
      border = {
        width = 2;
        radius = 10;
      };
    };
  };
}
