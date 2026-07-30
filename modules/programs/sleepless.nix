{
  flake.modules.darwin.sleepless =
    { config, ... }:
    {
      homebrew.casks = [
        {
          name = "aboudjem/tap/sleepless";
          trusted = true;
        }
      ];

      # Permit only the two pmset commands Sleepless uses to toggle
      # lid-close sleep without prompting for an administrator password.
      security.sudo.extraConfig = ''
        ${config.host.user.name} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
      '';
    };
}
