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
    # Work repos get the work email automatically
    includes = [
      {
        condition = "gitdir:~/code/work/";
        contents.user.email = settings.git.workEmail;
      }
    ];
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
}
