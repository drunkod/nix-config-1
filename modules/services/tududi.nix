{ inputs, ... }:

{
  flake.modules.homeManager.tududi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        escapeShellArg
        hasPrefix
        mkEnableOption
        mkIf
        mkMerge
        mkOption
        types
        ;

      cfg = config.services.tududi;
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      system = pkgs.stdenv.hostPlatform.system;
      defaultStateDirectory = "${config.home.homeDirectory}/.local/share/tududi";
      defaultLogDirectory = "${config.home.homeDirectory}/.local/state/tududi";
      bracketHost = host: if host == "::1" then "[::1]" else host;
      localOrigin = "http://${bracketHost cfg.host}:${toString cfg.port}";
      defaultLoopbackOrigins = [
        "http://localhost:${toString cfg.port}"
        "http://127.0.0.1:${toString cfg.port}"
        "http://[::1]:${toString cfg.port}"
      ];
      effectiveAllowedOrigins = cfg.allowedOrigins;
      effectiveFrontendUrl = if cfg.frontendUrl == null then localOrigin else cfg.frontendUrl;
      effectiveBackendUrl = if cfg.backendUrl == null then localOrigin else cfg.backendUrl;

      upstreamPackage = inputs.tududi.packages.${system}.default;
      darwinPackage = upstreamPackage.overrideAttrs (old: {
        # The upstream derivation builds successfully on aarch64-darwin when
        # unsupported-system checks are bypassed. Only relax its incorrect
        # Linux-only metadata here. In particular, do not replace
        # nativeBuildInputs: buildNpmPackage injects npm/node setup hooks there.
        meta = (old.meta or { }) // {
          platforms = lib.platforms.darwin;
        };
      });

      appDir = "${cfg.package}/libexec/tududi/backend";
      nodeBin = "${cfg.nodePackage}/bin/node";
      sequelizeCli = "${cfg.package}/libexec/tududi/node_modules/.bin/sequelize-cli";
      serviceLabel = "org.nix-community.home.tududi";
      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;

      sessionSecretFile =
        if cfg.sops.enable then config.sops.secrets."tududi-session-secret".path else cfg.sessionSecretFile;
      adminPasswordFile =
        if cfg.sops.enable then config.sops.secrets."tududi-admin-password".path else cfg.adminPasswordFile;
      apiTokenFile =
        if cfg.sops.enable then config.sops.secrets."tududi-api-token".path else cfg.apiTokenFile;
      generatedSessionSecretFile = "${cfg.stateDirectory}/session-secret";
      bootstrapAdminPasswordFile = "${cfg.stateDirectory}/bootstrap-admin-password";
      bootstrapAdminMarker = "${cfg.stateDirectory}/bootstrap-admin-provisioned";

      server = pkgs.writeShellApplication {
        name = "tududi-server";
        runtimeInputs = with pkgs; [
          coreutils
          openssl
        ];
        text = ''
          set -euo pipefail
          umask 077

          state_dir=${escapeShellArg cfg.stateDirectory}
          db_file=${escapeShellArg cfg.dbFile}
          db_dir=${escapeShellArg (builtins.dirOf cfg.dbFile)}
          upload_dir=${escapeShellArg cfg.uploadDirectory}
          log_dir=${escapeShellArg cfg.logDirectory}
          admin_email=${escapeShellArg cfg.adminEmail}
          session_secret_file=${escapeShellArg (if sessionSecretFile == null then "" else sessionSecretFile)}
          generated_session_secret_file=${escapeShellArg generatedSessionSecretFile}
          admin_password_file=${escapeShellArg (if adminPasswordFile == null then "" else adminPasswordFile)}
          bootstrap_admin_password_file=${escapeShellArg bootstrapAdminPasswordFile}
          bootstrap_admin_marker=${escapeShellArg bootstrapAdminMarker}
          provision_bootstrap_admin=0

          mkdir -p "$state_dir" "$db_dir" "$upload_dir" "$log_dir"
          chmod 700 "$state_dir" "$db_dir" "$upload_dir" "$log_dir"

          if [ -n "$session_secret_file" ]; then
            [ -s "$session_secret_file" ] || {
              echo "Tududi: configured session secret file is missing or empty: $session_secret_file" >&2
              exit 1
            }
            # Once an explicit secret source is active, remove the obsolete
            # locally-generated copy so there is only one source of truth.
            rm -f "$generated_session_secret_file"
          else
            session_secret_file="$generated_session_secret_file"
            if [ ! -s "$session_secret_file" ]; then
              openssl rand -hex 64 >"$session_secret_file"
              chmod 600 "$session_secret_file"
            fi
          fi

          export NODE_ENV=production
          export PORT=${escapeShellArg (toString cfg.port)}
          export HOST=${escapeShellArg cfg.host}
          export DB_FILE="$db_file"
          export TUDUDI_ALLOWED_ORIGINS=${escapeShellArg (lib.concatStringsSep "," effectiveAllowedOrigins)}
          export TUDUDI_UPLOAD_PATH="$upload_dir"
          # Tududi treats true as the single-hop value 1 but emits a warning;
          # pass 1 directly for the Cloudflare reverse-proxy case.
          export TUDUDI_TRUST_PROXY=${escapeShellArg (if cfg.trustProxy then "1" else "false")}
          TUDUDI_SESSION_SECRET="$(<"$session_secret_file")"
          export TUDUDI_SESSION_SECRET
          export TUDUDI_USER_EMAIL="$admin_email"
          export FRONTEND_URL=${escapeShellArg effectiveFrontendUrl}
          export BACKEND_URL=${escapeShellArg effectiveBackendUrl}
          export SWAGGER_ENABLED=false
          export DISABLE_SCHEDULER=false
          export DISABLE_TELEGRAM=true
          export FF_ENABLE_BACKUPS=false
          export FF_ENABLE_CALDAV=false
          export FF_ENABLE_CALENDAR=false
          export FF_ENABLE_HABITS=false
          export FF_ENABLE_MCP=${escapeShellArg (if cfg.mcp.enable then "true" else "false")}
          export ENABLE_EMAIL=false
          export OIDC_ENABLED=false
          export PASSWORD_AUTH_ENABLED=true
          export COOKIE_SECURE=auto
          export DISABLE_HSTS=false
          export RATE_LIMITING_ENABLED=true
          export NODE_PATH=${escapeShellArg "${cfg.package}/libexec/tududi/node_modules"}

          if [ -n "$admin_password_file" ]; then
            [ -s "$admin_password_file" ] || {
              echo "Tududi: configured admin password file is missing or empty: $admin_password_file" >&2
              exit 1
            }
            TUDUDI_USER_PASSWORD="$(<"$admin_password_file")"
            export TUDUDI_USER_PASSWORD
            # The bootstrap password becomes invalid once declarative password
            # management is enabled; do not leave or later display it.
            rm -f "$bootstrap_admin_password_file"
          elif [ -n "$admin_email" ] && [ ! -f "$bootstrap_admin_marker" ]; then
            if [ ! -s "$bootstrap_admin_password_file" ]; then
              openssl rand -base64 24 >"$bootstrap_admin_password_file"
              chmod 600 "$bootstrap_admin_password_file"
            fi
            TUDUDI_USER_PASSWORD="$(<"$bootstrap_admin_password_file")"
            export TUDUDI_USER_PASSWORD
            provision_bootstrap_admin=1
          fi

          cd ${escapeShellArg appDir}

          if [ ! -f "$DB_FILE" ]; then
            echo "Tududi: creating database at $DB_FILE"
            ${nodeBin} scripts/db-init.js
          fi

          echo "Tududi: running database migrations"
          ${nodeBin} ${sequelizeCli} db:migrate --config config/database.js
          ${nodeBin} scripts/db-status.js

          if [ -n "''${TUDUDI_USER_EMAIL:-}" ] && [ -n "''${TUDUDI_USER_PASSWORD:-}" ]; then
            if [ "$provision_bootstrap_admin" -eq 1 ]; then
              ${nodeBin} scripts/user-create.js "$TUDUDI_USER_EMAIL" "$TUDUDI_USER_PASSWORD" true
              touch "$bootstrap_admin_marker"
              chmod 600 "$bootstrap_admin_marker"
            else
              # With an explicit secret file, the configured admin password is
              # declarative and is reconciled on each service start.
              ${nodeBin} scripts/user-create.js "$TUDUDI_USER_EMAIL" "$TUDUDI_USER_PASSWORD" true
            fi
          fi

          exec ${nodeBin} app.js
        '';
      };

      mcpStdio = pkgs.writeShellApplication {
        name = "tududi-mcp-stdio";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail

          token_file=${escapeShellArg (if apiTokenFile == null then "" else apiTokenFile)}
          if [ -z "$token_file" ] || [ ! -s "$token_file" ]; then
            echo "Tududi MCP: API token is not configured." >&2
            echo "Create a Tududi API token in Profile -> API Keys, store it in SOPS, then enable services.tududi.sops." >&2
            exit 1
          fi

          export NODE_ENV=production
          export DB_FILE=${escapeShellArg cfg.dbFile}
          export TUDUDI_UPLOAD_PATH=${escapeShellArg cfg.uploadDirectory}
          TUDUDI_API_TOKEN="$(<"$token_file")"
          export TUDUDI_API_TOKEN
          export MCP_SERVER_NAME=${escapeShellArg cfg.mcp.serverName}
          export FF_ENABLE_MCP=true
          export NODE_PATH=${escapeShellArg "${cfg.package}/libexec/tududi/node_modules"}

          cd ${escapeShellArg appDir}
          exec ${nodeBin} modules/mcp/server.js
        '';
      };

      bootstrapCredentials = pkgs.writeShellApplication {
        name = "tududi-bootstrap-credentials";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          admin_email=${escapeShellArg cfg.adminEmail}
          password_file=${escapeShellArg bootstrapAdminPasswordFile}
          managed_password_file=${escapeShellArg (if adminPasswordFile == null then "" else adminPasswordFile)}
          printf 'Email: %s\n' "$admin_email"
          if [ -n "$managed_password_file" ]; then
            echo "Password is managed by the configured secret file and is not printed."
          elif [ -s "$password_file" ]; then
            printf 'Password: '
            cat "$password_file"
            printf '\n'
            echo "Password file: $password_file (mode 0600)"
          else
            echo "Bootstrap password has not been generated yet; start/restart Tududi first."
          fi
        '';
      };

      health = pkgs.writeShellApplication {
        name = "tududi-health";
        runtimeInputs = with pkgs; [ curl ];
        text = ''
          set -euo pipefail
          curl --fail --silent --show-error --max-time 5 ${escapeShellArg "${localOrigin}/api/health"}
          printf '\n'
        '';
      };

      restart = pkgs.writeShellApplication {
        name = "tududi-restart";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          exec /bin/launchctl kickstart -k "gui/$UID/${serviceLabel}"
        '';
      };
    in
    {
      options.services.tududi = {
        enable = mkEnableOption "Tududi task management service for Home Manager on macOS";

        package = mkOption {
          type = types.package;
          default = darwinPackage;
          description = "Tududi package. The default preserves the upstream package and only relaxes its Linux-only platform metadata for Darwin.";
        };

        nodePackage = mkOption {
          type = types.package;
          default = pkgs.nodejs_22;
          description = "Node.js runtime used by Tududi and its MCP stdio server.";
        };

        host = mkOption {
          type = types.enum [
            "127.0.0.1"
            "localhost"
            "::1"
          ];
          default = "127.0.0.1";
          description = "Loopback address for the local Tududi HTTP service.";
        };

        port = mkOption {
          type = types.port;
          default = 3002;
          description = "Local Tududi HTTP port.";
        };

        stateDirectory = mkOption {
          type = types.str;
          default = defaultStateDirectory;
          description = "Persistent Tududi state directory outside the Nix store.";
        };

        dbFile = mkOption {
          type = types.str;
          default = "${defaultStateDirectory}/db/production.sqlite3";
          description = "Persistent Tududi SQLite database path.";
        };

        uploadDirectory = mkOption {
          type = types.str;
          default = "${defaultStateDirectory}/uploads";
          description = "Persistent Tududi uploads directory.";
        };

        logDirectory = mkOption {
          type = types.str;
          default = defaultLogDirectory;
          description = "Tududi launchd log directory outside the Nix store.";
        };

        allowedOrigins = mkOption {
          type = types.listOf types.str;
          default = defaultLoopbackOrigins;
          description = "CORS origins. Defaults to localhost, 127.0.0.1, and [::1] on the configured port.";
        };

        trustProxy = mkOption {
          type = types.bool;
          default = true;
          description = "Trust the first reverse-proxy hop. Enabled because the optional Quick Tunnel terminates HTTPS upstream.";
        };

        frontendUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Frontend URL. Null uses the local loopback origin.";
        };

        backendUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Backend URL. Null uses the local loopback origin.";
        };

        adminEmail = mkOption {
          type = types.str;
          default = "admin@tududi.invalid";
          description = "Admin email used for initial provisioning. The reserved .invalid domain avoids accidental real email delivery.";
        };

        sessionSecretFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional runtime file containing TUDUDI_SESSION_SECRET. When null, a persistent local secret is generated in stateDirectory.";
        };

        adminPasswordFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional runtime file containing the initial admin password.";
        };

        apiTokenFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional runtime file containing the tt_ Tududi API token used by stdio MCP.";
        };

        autoStart = mkOption {
          type = types.bool;
          default = true;
          description = "Start Tududi at login through a Home Manager launchd agent.";
        };

        mcp = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Tududi's MCP feature and register the local stdio MCP server.";
          };
          serverName = mkOption {
            type = types.strMatching "[A-Za-z0-9][A-Za-z0-9._-]*";
            default = "tududi";
            description = "MCP server name exposed by Tududi's stdio server.";
          };
        };

        sops = {
          enable = mkEnableOption "SOPS-backed Tududi session, admin, and MCP API secrets";
          sopsFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Encrypted SOPS YAML containing tududi/session-secret, tududi/admin-password, and tududi/api-token.";
          };
          sessionSecretKey = mkOption {
            type = types.str;
            default = "tududi/session-secret";
          };
          adminPasswordKey = mkOption {
            type = types.str;
            default = "tududi/admin-password";
          };
          apiTokenKey = mkOption {
            type = types.str;
            default = "tududi/api-token";
          };
        };
      };

      config = mkIf cfg.enable (mkMerge [
        {
          assertions = [
            {
              assertion = isDarwin;
              message = "services.tududi is the Home Manager/nix-darwin adapter and currently supports Darwin only.";
            }
            {
              assertion = hasPrefix "/" cfg.stateDirectory && hasPrefix "/" cfg.dbFile && hasPrefix "/" cfg.uploadDirectory;
              message = "Tududi stateDirectory, dbFile, and uploadDirectory must be absolute paths.";
            }
            {
              assertion = hasPrefix "/" cfg.logDirectory && isOutsideNixStore cfg.logDirectory;
              message = "Tududi logs must use an absolute path outside the Nix store.";
            }
            {
              assertion = isOutsideNixStore cfg.stateDirectory && isOutsideNixStore cfg.dbFile && isOutsideNixStore cfg.uploadDirectory;
              message = "Tududi persistent state must remain outside the Nix store.";
            }
            {
              assertion = !cfg.sops.enable || cfg.sops.sopsFile != null;
              message = "services.tududi.sops.sopsFile is required when SOPS integration is enabled.";
            }
          ];

          home.packages = [
            cfg.package
            bootstrapCredentials
            health
            restart
            server
          ] ++ lib.optional cfg.mcp.enable mcpStdio;

          home.activation.tududiRuntimeDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p ${escapeShellArg cfg.stateDirectory}
            run mkdir -p ${escapeShellArg (builtins.dirOf cfg.dbFile)}
            run mkdir -p ${escapeShellArg cfg.uploadDirectory}
            run mkdir -p ${escapeShellArg cfg.logDirectory}
            run chmod 700 ${escapeShellArg cfg.stateDirectory}
            run chmod 700 ${escapeShellArg (builtins.dirOf cfg.dbFile)}
            run chmod 700 ${escapeShellArg cfg.uploadDirectory}
            run chmod 700 ${escapeShellArg cfg.logDirectory}
          '';

          launchd.agents.tududi = {
            enable = true;
            domain = "gui";
            config = {
              Label = serviceLabel;
              ProgramArguments = [ "${server}/bin/tududi-server" ];
              WorkingDirectory = appDir;
              RunAtLoad = cfg.autoStart;
              KeepAlive = {
                SuccessfulExit = false;
              };
              ThrottleInterval = 10;
              ProcessType = "Background";
              StandardOutPath = "${cfg.logDirectory}/stdout.log";
              StandardErrorPath = "${cfg.logDirectory}/stderr.log";
            };
          };

          programs.mcp.servers = mkIf cfg.mcp.enable {
            tududi = {
              command = lib.getExe mcpStdio;
            };
          };

          # These are intentionally short aliases, not identity aliases.
          home.shellAliases = {
            td-bootstrap-credentials = "tududi-bootstrap-credentials";
            td-health = "tududi-health";
            td-restart = "tududi-restart";
            td-mcp-stdio = "tududi-mcp-stdio";
          };
        }

        (mkIf cfg.sops.enable {
          sops.secrets."tududi-session-secret" = {
            sopsFile = cfg.sops.sopsFile;
            key = cfg.sops.sessionSecretKey;
            mode = "0400";
          };
          sops.secrets."tududi-admin-password" = {
            sopsFile = cfg.sops.sopsFile;
            key = cfg.sops.adminPasswordKey;
            mode = "0400";
          };
          sops.secrets."tududi-api-token" = {
            sopsFile = cfg.sops.sopsFile;
            key = cfg.sops.apiTokenKey;
            mode = "0400";
          };
        })
      ]);
    };
}