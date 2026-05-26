{
  config,
  lib,
  profile ? "standard",
}:
let
  baseAllow = [
    "Glob(*)"
    "Grep(*)"
    "LS(*)"
    "Read(*)"
    "Search(*)"
    "Task(*)"
    "TodoWrite(*)"
    "Bash(git status)"
    "Bash(git log:*)"
    "Bash(git diff:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(git remote:*)"
    "Bash(ls:*)"
    "Bash(find:*)"
    "Bash(cat:*)"
    "Bash(head:*)"
    "Bash(tail:*)"
    "Bash(nix eval:*)"
    "Bash(nix flake show:*)"
    "Bash(nix flake metadata:*)"
    "mcp__github__search_repositories"
    "mcp__github__get_file_contents"
    "mcp__sequential-thinking__sequentialthinking"
    "mcp__filesystem__read_file"
    "mcp__filesystem__read_text_file"
    "mcp__filesystem__read_media_file"
    "mcp__filesystem__read_multiple_files"
    "mcp__filesystem__list_directory"
    "mcp__filesystem__list_directory_with_sizes"
    "mcp__filesystem__directory_tree"
    "mcp__filesystem__search_files"
    "mcp__filesystem__get_file_info"
    "mcp__filesystem__list_allowed_directories"
    "WebFetch(domain:github.com)"
    "WebFetch(domain:wiki.hyprland.org)"
    "WebFetch(domain:wiki.hypr.land)"
    "WebFetch(domain:raw.githubusercontent.com)"
    "WebFetch(domain:snowfall.org)"
    "WebFetch(domain:devenv.sh)"
  ];

  standardAllow = baseAllow ++ [
    "Bash(git add:*)"
    "Bash(nix search:*)"
    "Bash(nix log:*)"
    "Bash(nix path-info:*)"
    "Bash(nix show-config:*)"
    "Bash(nix flake check:*)"
    "Bash(mkdir:*)"
    "Bash(chmod:*)"
    "Bash(rg:*)"
    "Bash(grep:*)"
    "Bash(systemctl list-units:*)"
    "Bash(systemctl list-timers:*)"
    "Bash(systemctl status:*)"
    "Bash(journalctl:*)"
    "Bash(dmesg:*)"
    "Bash(env)"
    "Bash(claude --version)"
    "Bash(nh search:*)"
    "Bash(pactl list:*)"
    "Bash(pw-top)"
    "Bash(hyprctl dispatch:*)"
    "Bash(swaymsg:*)"
    "Bash(swaync-client:*)"
    "Bash(uwsm check:*)"
    "Bash(coredumpctl list:*)"
    "mcp__mulesoft-analyzer"
    "Read(${config.home.homeDirectory}/Documents/github/home-manager/**)"
    "Read(${config.home.homeDirectory}/.config/sway/**)"
  ];

  autonomousAllow = standardAllow ++ [
    "Bash(git commit:*)"
    "Bash(git checkout:*)"
    "Bash(git switch:*)"
    "Bash(git stash:*)"
    "Bash(git restore:*)"
    "Bash(git reset:*)"
    "Bash(rm:*)"
  ];

  standardAsk = [
    "Bash(git checkout:*)"
    "Bash(git commit:*)"
    "Bash(git merge:*)"
    "Bash(git pull:*)"
    "Bash(git push:*)"
    "Bash(git rebase:*)"
    "Bash(git reset:*)"
    "Bash(git restore:*)"
    "Bash(git stash:*)"
    "Bash(git switch:*)"
    "Bash(cp:*)"
    "Bash(mv:*)"
    "Bash(rm:*)"
    "Bash(rm -rf:*)"
    "Bash(dd:*)"
    "Bash(mkfs:*)"
    "Bash(shutdown)"
    "Bash(shutdown:*)"
    "Bash(reboot)"
    "Bash(reboot:*)"
    "Bash(systemctl disable:*)"
    "Bash(systemctl enable:*)"
    "Bash(systemctl mask:*)"
    "Bash(systemctl reload:*)"
    "Bash(systemctl restart:*)"
    "Bash(systemctl start:*)"
    "Bash(systemctl stop:*)"
    "Bash(systemctl unmask:*)"
    "Bash(curl:*)"
    "Bash(ping:*)"
    "Bash(rsync:*)"
    "Bash(scp:*)"
    "Bash(ssh:*)"
    "Bash(wget:*)"
    "Bash(nix build:*)"
    "Bash(nix run:*)"
    "Bash(nix shell:*)"
    "Bash(nixos-rebuild:*)"
    "Bash(sudo:*)"
    "Bash(kill:*)"
    "Bash(killall:*)"
    "Bash(pkill:*)"
  ];

  autonomousAsk = [
    "Bash(git push:*)"
    "Bash(git merge:*)"
    "Bash(git rebase:*)"
    "Bash(systemctl:*)"
    "Bash(nix build:*)"
    "Bash(nix run:*)"
    "Bash(nix shell:*)"
    "Bash(nixos-rebuild:*)"
    "Bash(sudo:*)"
    "Bash(curl:*)"
    "Bash(rsync:*)"
    "Bash(scp:*)"
    "Bash(ssh:*)"
    "Bash(wget:*)"
    "Bash(kill:*)"
    "Bash(killall:*)"
    "Bash(pkill:*)"
    "Bash(rm -rf:*)"
    "Bash(dd:*)"
    "Bash(mkfs:*)"
    "Bash(shutdown)"
    "Bash(shutdown:*)"
    "Bash(reboot)"
    "Bash(reboot:*)"
  ];
in
{
  allow =
    if profile == "autonomous" then
      autonomousAllow
    else if profile == "standard" then
      standardAllow
    else
      baseAllow;

  ask =
    if profile == "autonomous" then
      autonomousAsk
    else if profile == "standard" then
      standardAsk
    else
      standardAsk ++ standardAllow;

  deny = [
    "Bash(rm -rf /*)"
    "Bash(rm -rf /)"
  ];

  defaultMode = if profile == "autonomous" then "acceptEdits" else "default";
}
