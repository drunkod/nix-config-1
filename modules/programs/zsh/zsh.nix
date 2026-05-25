{
  flake.modules.nixos.base =
    { config, pkgs, ... }:
    {

      users.users.${config.host.user.name} = {
        shell = pkgs.zsh;
      };

      programs = {
        zsh = {
          enable = true;
          autosuggestions.enable = true;
          syntaxHighlighting.enable = true;
          enableCompletion = true;
          histSize = 100000;

          ohMyZsh = {
            enable = true;
            plugins = [ "git" ];
          };

          shellInit = ''
            # Spaceship
            source ${pkgs.spaceship-prompt}/share/zsh/site-functions/prompt_spaceship_setup
            autoload -U promptinit; promptinit
            # Hook direnv
            #emulate zsh -c "$(direnv hook zsh)"

            #eval "$(direnv hook zsh)"
          '';
        };
      };
    };

  flake.modules.darwin.base =
    { config, pkgs, ... }:
    {
      users.users.${config.host.user.name} = {
        shell = pkgs.zsh;
      };

      programs.zsh.enable = true;
    };

  flake.modules.homeManager.zsh =
    {
      host,
      lib,
      pkgs,
      config,
      ...
    }:
    let
      inherit (lib.strings) fileContents;
      nativeHistory = !(config.programs.atuin.enable or false);
    in
    {
      home.file.".p10k.zsh".source = ./p10k.zsh;

      home.packages = with pkgs; [
        fd
        gh
        less
        pay-respects
        zsh-powerlevel10k
      ];

      home.sessionVariables = {
        ZSH_CACHE_DIR = "${config.xdg.cacheHome}/zsh";
      };

      programs = {
        atuin = {
          enable = true;
          enableBashIntegration = true;
          enableFishIntegration = true;
          enableZshIntegration = true;
          enableNushellIntegration = true;
          daemon.enable = true;
          settings = {
            enter_accept = true;
            filter_mode = "workspace";
            keymap_mode = "auto";
            show_preview = true;
            style = "auto";
            update_check = false;
            workspaces = true;
            history_filter = [
              "^(sudo reboot)$"
              "^(reboot)$"
            ];
          };
        };

        bat.enable = true;

        btop.enable = true;

        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        eza = {
          enable = true;
          package = pkgs.eza;
          enableBashIntegration = true;
          enableZshIntegration = true;
          enableFishIntegration = true;
          extraOptions = [
            "--group-directories-first"
            "--header"
            "--hyperlink"
            "--follow-symlinks"
          ];
          git = true;
          icons = "auto";
        };

        fastfetch.enable = true;

        fzf = {
          enable = true;
          defaultCommand = "${lib.getExe pkgs.fd} --type=f --hidden --exclude=.git";
          defaultOptions = [
            "--layout=reverse"
            "--exact"
            "--bind=alt-p:toggle-preview,alt-a:select-all"
            "--multi"
            "--no-mouse"
            "--info=inline"
            "--ansi"
            "--with-nth=1.."
            "--pointer='> '"
            "--header-first"
            "--border=rounded"
          ];
          enableBashIntegration = true;
          enableZshIntegration = false;
          enableFishIntegration = true;
          tmux.enableShellIntegration = true;
        };

        pay-respects = {
          enable = true;
          enableZshIntegration = true;
        };

        ripgrep = {
          enable = true;
          arguments = [
            "--hyperlink-format=kitty"
          ];
        };

        zoxide = {
          enable = true;
          enableBashIntegration = true;
          enableZshIntegration = true;
          enableFishIntegration = true;
        };

        zsh = {
          enable = true;
          enableCompletion = true;
          autocd = true;
          dotDir = "${config.xdg.configHome}/zsh";
          enableVteIntegration = true;
          history = lib.mkIf nativeHistory {
            path = "${config.xdg.dataHome}/zsh/zsh_history";
            extended = true;
            save = 100000;
            size = 100000;
            expireDuplicatesFirst = true;
            ignoreDups = true;
            ignoreSpace = true;
            saveNoDups = true;
            findNoDups = true;
          };
          historySubstringSearch.enable = true;
          setOptions = [
            "AUTO_LIST"
            "AUTO_PARAM_SLASH"
            "AUTO_PUSHD"
            "ALWAYS_TO_END"
            "CORRECT"
            "INTERACTIVE_COMMENTS"
            "PUSHD_IGNORE_DUPS"
            "PUSHD_TO_HOME"
            "PUSHD_SILENT"
            "NOTIFY"
            "PROMPT_SUBST"
            "MULTIOS"
            "NOFLOWCONTROL"
            "NO_CORRECT_ALL"
            "NO_NOMATCH"
          ]
          ++ lib.optionals nativeHistory [
            "HIST_VERIFY"
            "NO_HIST_BEEP"
          ];
          sessionVariables = {
            LC_ALL = "en_US.UTF-8";
            KEYTIMEOUT = 0;
          };
          completionInit = ''
            autoload -U compinit
            zmodload zsh/complist

            _comp_options+=(globdots)
            zcompdump="$XDG_DATA_HOME"/zsh/.zcompdump-"$ZSH_VERSION"-"$(date +%F)"
            compinit -d "$zcompdump"

            if [[ -s "$zcompdump" && (! -s "$zcompdump".zwc || "$zcompdump" -nt "$zcompdump".zwc) ]]; then
              zcompile "$zcompdump"
            fi

            autoload -U +X bashcompinit && bashcompinit

            ${fileContents ./rc/comp.zsh}
          '';
          syntaxHighlighting = {
            enable = true;
            highlighters = [
              "brackets"
              "pattern"
              "regexp"
              "cursor"
              "root"
              "line"
            ];
          };
          shellAliases = {
            la = lib.mkForce "${lib.getExe config.programs.eza.package} -lah --tree";
            tree = lib.mkForce "${lib.getExe config.programs.eza.package} --tree --icons=always";
            finder = "ofd";
            atuin-prune-failed = "atuin search --exclude-exit 0 --delete \"\"";
            atuin-prune-failed-dry-run = "atuin search --exclude-exit 0 --format \"{exit}\t{time}\t{command}\" | rg '^[1-9][0-9]*\t'";
          };
          initContent = lib.mkMerge [
            (lib.mkOrder 50 ''
              if [[ -n "''${NIXPKGS_REVIEW_ROOT:-}" ]] || [[ -n "''${IN_NIX_SHELL:-}" && "''${PWD:-}" == "''${XDG_CACHE_HOME:-''${HOME}/.cache}/nixpkgs-review/"* ]]; then
                return
              fi
            '')
            (lib.mkOrder 450 (
              lib.optionalString nativeHistory ''
                function zshaddhistory() {
                  LASTHIST=''${1//\\$'\n'/}
                  return 2
                }

                function precmd() {
                  if [[ $? == 0 && -n ''${LASTHIST//[[:space:]\n]/} && -n $HISTFILE ]] ; then
                    print -sr -- ''${=''${LASTHIST%%'\n'}}
                  fi
                }

                if autoload history-search-end; then
                  zle -N history-beginning-search-backward-end history-search-end
                  zle -N history-beginning-search-forward-end  history-search-end
                fi
              ''
            ))
            (lib.mkOrder 500 ''
              source <(${lib.getExe config.programs.fzf.package} --zsh)
              source ${config.programs.git.package}/share/git/contrib/completion/git-prompt.sh
            '')
            (lib.mkOrder 600 ''
              ${fileContents ./rc/binds.zsh}
              ${fileContents ./rc/modules.zsh}
              ${fileContents ./rc/fzf-tab.zsh}
              ${fileContents ./rc/misc.zsh}

              ${lib.optionalString nativeHistory ''
                ZSH_AUTOSUGGEST_HISTORY_IGNORE=$'*\n*'
              ''}

              ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#757575'
            '')
            (lib.mkOrder 700 ''
            source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
            [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
            '')
            (lib.mkOrder 750 (lib.optionalString (host.system == "aarch64-darwin") ''
              ssh-add --apple-load-keychain &>/dev/null
            ''))
            (lib.mkOrder 760 (lib.optionalString (host.name == "MacbookAirM1") ''
              export PATH=$PATH:`cat $HOME/Library/Application\ Support/Garmin/ConnectIQ/current-sdk.cfg`/bin
            ''))
            (lib.mkOrder 5000 (lib.optionalString config.programs.fastfetch.enable "fastfetch"))
          ];
          plugins = [
            {
              name = "fzf-tab";
              file = "share/fzf-tab/fzf-tab.plugin.zsh";
              src = pkgs.zsh-fzf-tab;
            }
            {
              name = "zsh-nix-shell";
              file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
              src = pkgs.zsh-nix-shell;
            }
            {
              name = "zsh-vi-mode";
              src = pkgs.zsh-vi-mode;
              file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
            }
            {
              name = "zsh-autosuggestions";
              file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
              src = pkgs.zsh-autosuggestions;
            }
            {
              name = "zsh-better-npm-completion";
              file = "share/zsh-better-npm-completion";
              src = pkgs.zsh-better-npm-completion;
            }
            {
              name = "zsh-command-time";
              file = "share/zsh/plugins/zsh-command-time/zsh-command-time.plugin.zsh";
              src = pkgs.zsh-command-time;
            }
            {
              name = "zsh-you-should-use";
              file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
              src = pkgs.zsh-you-should-use;
            }
          ];
        };
      };
    };
}
