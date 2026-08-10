{
  inputs,
  ...
}:

{
  flake.modules.homeManager.noctalia =
    {
      osConfig,
      pkgs,
      host,
      ...
    }:
    let
      noctaliaPackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      legacyPluginRegistry = "https://github.com/noctalia-dev/legacy-v4-plugins";
    in
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      home.packages = with pkgs; [
        quickshell
      ];

      programs.noctalia-shell = {
        enable = true;
        package = noctaliaPackage;

        settings = {
          bar = {
            barType = "simple";
            position = "top";
            density = "default";
            showCapsule = true;
            capsuleColorKey = "none";
            outerCorners = false;
            widgets = {
              left =
                if (osConfig.programs ? niri && osConfig.programs.niri.enable) then
                  [
                    {
                      id = "Launcher";
                    }
                    {
                      id = "Taskbar";
                    }
                  ]
                else
                  [
                    {
                      id = "Launcher";
                    }
                    {
                      id = "Workspace";
                      showApplications = true;
                      colorizeIcons = true;
                      hideUnoccupied = false;
                      showLabelsOnlyWhenOccupied = false;
                    }
                  ];
              center =
                if (osConfig.programs ? niri && osConfig.programs.niri.enable) then
                  [
                    {
                      id = "Workspace";
                    }
                  ]
                else
                  [ ];
              right = [
                {
                  id = "MediaMini";
                  hideMode = "hidden";
                  hideWhenIdle = true;
                  maxWidth = 30;
                  useFixedWidth = true;
                  showVisualizer = true;
                  visualizerType = "mirrored";
                  showAlbumArt = true;
                  showProgressRing = true;
                  compactMode = true;
                  compactShowAlbumArt = true;
                  compactShowVisualizer = true;
                }
                {
                  id = "Tray";
                  drawerEnabled = false;
                }
                {
                  id = "Bluetooth";
                }
                {
                  id = "Volume";
                }
                {
                  id = "NotificationHistory";
                }
                {
                  id = "plugin:privacy-indicator";
                  defaultSettings = {
                    activeColor = "primary";
                    hideInactive = true;
                    inactiveColor = "none";
                    removeMargins = false;
                  };
                }
                {
                  id = "ControlCenter";
                }
                {
                  id = "Clock";
                }
              ];
            };
          };
          location = {
            name = "Hasselt";
          };
          dock = {
            enabled = false;
            position = "bottom";
            displayMode = "auto_hide";
            colorizeIcons = true;
            animationSpeed = 2;
          };
          colorSchemes = {
            useWallpaperColors = true;
            darkMode = true;
            generationMethod = "tonal-spot";
          };
          audio = {
            visualizerType = "mirrored";
          };
          hooks = {
            enabled = true;
            startup = "${noctaliaPackage}/bin/noctalia-shell ipc call lockScreen lock";
          };
        };

        plugins = {
          sources = [
            {
              enabled = true;
              name = "Official Noctalia v4 Plugins";
              url = legacyPluginRegistry;
            }
          ];
          states = {
            privacy-indicator = {
              enabled = true;
              sourceUrl = legacyPluginRegistry;
            };
          };
          version = 2;
        };

        pluginSettings = {
          privacy-indicator = {
            hideInactive = true;
            removeMargins = true;
          };
        };
      };
    };
}
