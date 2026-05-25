{
  flake.modules.homeManager.kitty =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      kittyShellFunctions = ''
        clipboard() {
          if [ -n "''${KITTY_WINDOW_ID:-}" ]; then
            kitten clipboard "$@"
          else
            printf '%s\n' 'clipboard is only available inside kitty' >&2
            return 1
          fi
        }

        icat() {
          if [ -n "''${KITTY_WINDOW_ID:-}" ]; then
            kitten icat "$@"
          else
            printf '%s\n' 'icat is only available inside kitty' >&2
            return 1
          fi
        }

        kdiff() {
          if [ -n "''${KITTY_WINDOW_ID:-}" ]; then
            kitten diff "$@"
          else
            command diff "$@"
          fi
        }

        kssh() {
          if [ -n "''${KITTY_WINDOW_ID:-}" ]; then
            kitten ssh "$@"
          else
            command ssh "$@"
          fi
        }
      '';
    in
    {
      programs = {
        bash.initExtra = kittyShellFunctions;

        kitty = {
          enable = true;
          enableGitIntegration = true;
          darwinLaunchOptions = [
            "--single-instance"
            "--listen-on=unix:/tmp/kitty.sock"
          ];
          keybindings = {
            "shift+enter" = "send_text all \\x1b[13;2u";
            "alt+enter" = "send_text all \\x1b[13;3u";
            "alt+shift+enter" = "send_text all \\x1b[13;4u";
            "ctrl+enter" = "send_text all \\x1b[13;5u";
            "ctrl+shift+v" = "paste_from_clipboard";
            "ctrl+shift+s" = "paste_from_selection";
            "ctrl+shift+c" = "copy_to_clipboard";
            "shift+insert" = "paste_from_selection";
            "ctrl+shift+up" = "scroll_line_up";
            "ctrl+shift+down" = "scroll_line_down";
            "ctrl+shift+k" = "scroll_line_up";
            "ctrl+shift+j" = "scroll_line_down";
            "ctrl+shift+page_up" = "scroll_page_up";
            "ctrl+shift+page_down" = "scroll_page_down";
            "ctrl+shift+home" = "scroll_home";
            "ctrl+shift+end" = "scroll_end";
            "ctrl+shift+h" = "show_scrollback";
            "ctrl+shift+enter" = "new_window";
            "ctrl+shift+n" = "new_os_window";
            "ctrl+shift+w" = "close_window";
            "ctrl+shift+]" = "next_window";
            "ctrl+shift+[" = "previous_window";
            "ctrl+shift+f" = "move_window_forward";
            "ctrl+shift+b" = "move_window_backward";
            "ctrl+shift+`" = "move_window_to_top";
            "ctrl+shift+1" = "first_window";
            "ctrl+shift+2" = "second_window";
            "ctrl+shift+3" = "third_window";
            "ctrl+shift+4" = "fourth_window";
            "ctrl+shift+5" = "fifth_window";
            "ctrl+shift+6" = "sixth_window";
            "ctrl+shift+7" = "seventh_window";
            "ctrl+shift+8" = "eighth_window";
            "ctrl+shift+9" = "ninth_window";
            "ctrl+shift+0" = "tenth_window";
            "ctrl+shift+right" = "next_tab";
            "ctrl+shift+left" = "previous_tab";
            "ctrl+shift+t" = "new_tab";
            "ctrl+shift+q" = "close_tab";
            "ctrl+shift+l" = "next_layout";
            "ctrl+shift+." = "move_tab_forward";
            "ctrl+shift+," = "move_tab_backward";
            "ctrl+shift+alt+t" = "set_tab_title";
            "ctrl+shift+equal" = "increase_font_size";
            "ctrl+shift+minus" = "decrease_font_size";
            "ctrl+shift+backspace" = "restore_font_size";
            "ctrl+shift+f6" = "set_font_size 16.0";
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            "cmd+opt+s" = "noop";
          };
          settings = {
            font_family = "FiraCode Nerd Font Mono";
            font_size = 13;
            adjust_line_height = 0;
            adjust_column_width = 0;
            box_drawing_scale = "0.001, 1, 1.5, 2";
            copy_on_select = "yes";
            strip_trailing_spaces = "always";
            clipboard_control = "write-clipboard write-primary read-clipboard read-primary";
            cursor_shape = "underline";
            cursor_blink_interval = -1;
            cursor_stop_blinking_after = "15.0";
            cursor_trail = 100;
            cursor_trail_decay = "0.1 0.4";
            scrollback_lines = 10000;
            scrollback_pager = "less";
            wheel_scroll_multiplier = "5.0";
            url_style = "double";
            open_url_with = "default";
            select_by_word_characters = ":@-./_~?& = %+#";
            click_interval = "0.5";
            mouse_hide_wait = -1;
            focus_follows_mouse = "no";
            repaint_delay = 8;
            input_delay = 2;
            sync_to_monitor = "no";
            visual_bell_duration = "0.0";
            enable_audio_bell = "yes";
            bell_on_tab = "yes";
            notify_on_cmd_finish = "unfocused";
            remember_window_size = "no";
            initial_window_width = 700;
            initial_window_height = 400;
            window_border_width = 0;
            window_margin_width = 0;
            window_padding_width = 0;
            inactive_text_alpha = "0.8";
            background_opacity = lib.mkDefault "0.90";
            background_blur = lib.mkDefault "20";
            dynamic_background_opacity = "yes";
            placement_strategy = "center";
            hide_window_decorations = "yes";
            confirm_os_window_close = -1;
            enabled_layouts = "*";
            tab_bar_edge = "bottom";
            tab_bar_margin_width = "0.0";
            tab_bar_min_tabs = 1;
            tab_bar_style = "powerline";
            tab_powerline_style = "slanted";
            tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{index}: {title}";
            active_tab_font_style = "bold";
            inactive_tab_font_style = "normal";
            shell = "${pkgs.zsh}/bin/zsh";
            close_on_child_death = "no";
            allow_remote_control = "socket-only";
            term = "xterm-kitty";
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty";
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            hide_window_decorations = "titlebar-only";
            macos_option_as_alt = "both";
            macos_custom_beam_cursor = "yes";
            macos_thicken_font = 0;
            macos_colorspace = "displayp3";
            macos_show_window_title_in = "none";
            text_composition_strategy = "1.0";
          };
          shellIntegration = {
            enableBashIntegration = true;
            enableFishIntegration = true;
            enableZshIntegration = true;
            mode = "no-title";
          };
        };

        zsh.initContent = lib.mkAfter kittyShellFunctions;
      };
    };

  flake.modules.darwin.kitty =
    { config, ... }:
    {
      homebrew = {
        enable = true;
        casks = [
          "kitty"
          "font-meslo-lg-nerd-font"
          "font-fira-code-nerd-font"
        ];
      };

      home-manager.users.${config.host.user.name} = {
        home.file = {
          ".ssh/config" = {
            text = ''
              Host *
                UseKeychain yes
                AddKeysToAgent yes
                SetEnv TERM=xterm-256color
            '';
          };
          ".config/kitty/kitty.conf" = {
            text = ''
              font_family FiraCode Nerd Font Mono
              font_size 13

              background_opacity 0.8
              background_blur 16

              window_margin_width 4
              single_window_margin_width 0
              active_border_color   #d0d0d0
              inactive_border_color #202020

              hide_window_decorations titlebar-only

              tab_bar_style powerline
              tab_powerline_style slanted

              confirm_os_window_close 0

              background            #202020
              foreground            #d0d0d0
              cursor                #d0d0d0
              selection_background  #303030
              color0                #151515
              color8                #505050
              color1                #ac4142
              color9                #ac4142
              color2                #7e8d50
              color10               #7e8d50
              color3                #e5b566
              color11               #e5b566
              color4                #6c99ba
              color12               #6c99ba
              color5                #9e4e85
              color13               #9e4e85
              color6                #7dd5cf
              color14               #7dd5cf
              color7                #d0d0d0
              color15               #f5f5f5
              selection_foreground  #202020

              map f1 new_window_with_cwd
              map cmd+t new_tab_with_cwd
              startup_session ~/.config/kitty/startup.conf

              shell_integration no-sudo
            '';
          };
        };
      };
    };
}
