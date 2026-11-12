{ settings, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = settings.fullName;
        email = settings.git.personalEmail;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rerere.enabled = true;
    };
    ignores = [
      ".direnv/"
      ".envrc.local"
      ".claude/worktrees/"
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };
}
