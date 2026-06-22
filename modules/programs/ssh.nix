{
  flake.modules.homeManager.ssh =
    { config, ... }:
    {
      home.file.".ssh/config" = {
        text = ''
          Host github.com
            HostName ssh.github.com
            Port 443
            User git
            IdentityFile ${config.home.homeDirectory}/.ssh/id_ed25519
            UseKeychain yes
            AddKeysToAgent yes

          Host *
            UseKeychain yes
            AddKeysToAgent yes
            SetEnv TERM=xterm-256color
        '';
      };
    };
}
