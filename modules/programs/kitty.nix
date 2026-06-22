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
      # macOS installs Kitty as a Homebrew cask from flake.modules.darwin.kitty.
      # Do not install the Nix Kitty package on Darwin, otherwise Spotlight/Finder
      # can show duplicate Kitty.app entries. Linux keeps a Nix-installed package.
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.kitty ];

      xdg.configFile = {
        "kitty/kitty.conf" = {
          text = ''
            font_family FiraCode Nerd Font Mono
            font_size 13
            adjust_line_height 0
            adjust_column_width 0
            box_drawing_scale 0.001, 1, 1.5, 2

            copy_on_select yes
            strip_trailing_spaces always
            clipboard_control write-clipboard write-primary read-clipboard read-primary

            cursor_shape underline
            cursor_blink_interval -1
            cursor_stop_blinking_after 15.0
            cursor_trail 100
            cursor_trail_decay 0.1 0.4

            scrollback_lines 10000
            scrollback_pager less
            wheel_scroll_multiplier 5.0

            url_style double
            open_url_with default
            select_by_word_characters :@-./_~?& = %+#
            click_interval 0.5
            mouse_hide_wait -1
            focus_follows_mouse no

            repaint_delay 8
            input_delay 2
            sync_to_monitor no
            visual_bell_duration 0.0
            enable_audio_bell yes
            bell_on_tab yes
            notify_on_cmd_finish unfocused

            remember_window_size no
            initial_window_width 700
            initial_window_height 400
            window_border_width 0
            window_margin_width 4
            single_window_margin_width 0
            window_padding_width 0
            inactive_text_alpha 0.8
            background_opacity 0.8
            background_blur 16
            dynamic_background_opacity yes
            placement_strategy center
            hide_window_decorations titlebar-only
            confirm_os_window_close 0

            enabled_layouts *
            tab_bar_edge bottom
            tab_bar_margin_width 0.0
            tab_bar_min_tabs 1
            tab_bar_style powerline
            tab_powerline_style slanted
            tab_title_template {fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{index}: {title}
            active_tab_font_style bold
            inactive_tab_font_style normal

            shell ${pkgs.zsh}/bin/zsh
            shell_integration no-sudo
            close_on_child_death no
            allow_remote_control socket-only
            listen_on unix:/tmp/kitty.sock
            term xterm-kitty

            macos_option_as_alt both
            macos_custom_beam_cursor yes
            macos_thicken_font 0
            macos_colorspace displayp3
            macos_show_window_title_in none
            text_composition_strategy 1.0

            active_border_color   #d0d0d0
            inactive_border_color #202020
            background            #202020
            foreground            #d0d0d0
            cursor                #d0d0d0
            selection_background  #303030
            selection_foreground  #202020
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

            map shift+enter send_text all \x1b[13;2u
            map alt+enter send_text all \x1b[13;3u
            map alt+shift+enter send_text all \x1b[13;4u
            map ctrl+enter send_text all \x1b[13;5u
            map ctrl+shift+v paste_from_clipboard
            map ctrl+shift+s paste_from_selection
            map ctrl+shift+c copy_to_clipboard
            map shift+insert paste_from_selection
            map ctrl+shift+up scroll_line_up
            map ctrl+shift+down scroll_line_down
            map ctrl+shift+k scroll_line_up
            map ctrl+shift+j scroll_line_down
            map ctrl+shift+page_up scroll_page_up
            map ctrl+shift+page_down scroll_page_down
            map ctrl+shift+home scroll_home
            map ctrl+shift+end scroll_end
            map ctrl+shift+h show_scrollback
            map ctrl+shift+enter new_window
            map ctrl+shift+n new_os_window
            map ctrl+shift+w close_window
            map ctrl+shift+] next_window
            map ctrl+shift+[ previous_window
            map ctrl+shift+f move_window_forward
            map ctrl+shift+b move_window_backward
            map ctrl+shift+` move_window_to_top
            map ctrl+shift+1 first_window
            map ctrl+shift+2 second_window
            map ctrl+shift+3 third_window
            map ctrl+shift+4 fourth_window
            map ctrl+shift+5 fifth_window
            map ctrl+shift+6 sixth_window
            map ctrl+shift+7 seventh_window
            map ctrl+shift+8 eighth_window
            map ctrl+shift+9 ninth_window
            map ctrl+shift+0 tenth_window
            map ctrl+shift+right next_tab
            map ctrl+shift+left previous_tab
            map ctrl+shift+t new_tab
            map ctrl+shift+q close_tab
            map ctrl+shift+l next_layout
            map ctrl+shift+. move_tab_forward
            map ctrl+shift+, move_tab_backward
            map ctrl+shift+alt+t set_tab_title
            map ctrl+shift+equal increase_font_size
            map ctrl+shift+minus decrease_font_size
            map ctrl+shift+backspace restore_font_size
            map ctrl+shift+f6 set_font_size 16.0
            map cmd+opt+s noop
            map f1 new_window_with_cwd
            map cmd+t new_tab_with_cwd
          '';
        };

        "kitty/startup.conf" = {
          text = ''
            # Keep this file managed by Home Manager so kitty startup_session can be
            # enabled later without creating an unmanaged dotfile.
          '';
        };
      };

      programs = {
        bash.initExtra = kittyShellFunctions;
        zsh.initContent = lib.mkAfter kittyShellFunctions;
      };
    };

  flake.modules.darwin.kitty = {
    homebrew = {
      enable = true;
      casks = [
        "kitty"
        "font-meslo-lg-nerd-font"
        "font-fira-code-nerd-font"
      ];
    };
  };
}
