{ config, lib, pkgs, ... }:
let
  inherit (lib)
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalAttrs
    types
    ;

  cfg = config.services.thoth;

  resolvedPackage =
    if cfg.package != null then
      cfg.package
    else if cfg.source != null && cfg.npmDepsHash != null && cfg.primeAgentPackage != null then
      pkgs.callPackage ../../packages/thoth.nix {
        src = cfg.source;
        npmDepsHash = cfg.npmDepsHash;
        primeAgent = cfg.primeAgentPackage;
      }
    else
      null;

  workspace = if cfg.workspace != null then cfg.workspace else cfg.home;
  agentDir = if cfg.agentDir != null then cfg.agentDir else "${cfg.home}/.prime/agent";
  environmentFiles = cfg.environmentFiles ++ optional (cfg.hindsight.environmentFile != null) cfg.hindsight.environmentFile;
  pythonEnv = pkgs.python313.withPackages (
    ps: with ps; [
      beautifulsoup4
      httpx
    ]
  );

  resourceLinks = [
    "extensions/prime-memory"
    "skills/browser"
    "skills/tailscale-serve"
    "skills/vault-memory"
    "skills/websearch"
  ];
  resourceLinkScript = concatStringsSep "\n" (
    map (
      resource:
      let
        target = "${agentDir}/${resource}";
        source = "${resolvedPackage}/share/thoth/agent/${resource}";
      in
      ''
        target=${lib.escapeShellArg target}
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          printf 'refusing to replace non-symlink Prime Agent resource: %s\\n' "$target" >&2
          exit 1
        fi
        ln -sfn ${lib.escapeShellArg source} "$target"
      ''
    ) resourceLinks
  );

  userOptions = {
    isSystemUser = true;
    group = cfg.group;
    home = cfg.home;
    createHome = true;
    shell = pkgs.bash;
    extraGroups = cfg.extraGroups;
  } // optionalAttrs (cfg.uid != null) { uid = cfg.uid; };
in
{
  options.services.thoth = {
    enable = mkEnableOption "Thoth Prime Agent Discord gateway";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Reproducible Thoth package override. Set this when the private Prime Agent
        source is supplied by another flake or package set.
      '';
    };

    source = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Fixed-output source tree for the Prime Agent AIO repository. It must contain
        integrations/discord-bot/package.json and package-lock.json. A working-tree
        path is not a reproducible package input and is intentionally not a default.
      '';
    };

    npmDepsHash = mkOption {
      type = types.nullOr types.str;
      default = "sha256-lIqh5Rd0MoT/MJ7oph4XeCO0xVfLvCtaahBX03s4ZPc=";
      description = "Hash for the source repository's pinned Discord npm dependency tree.";
    };

    primeAgentPackage = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../packages/prime-agent.nix { };
      description = ''
        Pinned Prime Agent npm package root. Override it only when a different
        audited release is required. The package is built inside Nix.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "thoth";
      description = "User that owns the Thoth gateway process and its runtime data.";
    };

    group = mkOption {
      type = types.str;
      default = "thoth";
      description = "Primary group for the Thoth service user.";
    };

    uid = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Optional fixed UID when the module creates the service user.";
    };

    createUser = mkOption {
      type = types.bool;
      default = true;
      description = "Create the configured service user and group.";
    };

    extraGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional groups for the service user.";
    };

    home = mkOption {
      type = types.str;
      default = "/var/lib/thoth";
      description = "HOME directory for Prime Agent state, auth, and installed resources.";
    };

    statePath = mkOption {
      type = types.str;
      default = "/var/lib/thoth/state";
      description = "Writable BOT_DATA_DIR for sessions, webhooks, uploads, and health state.";
    };

    cachePath = mkOption {
      type = types.str;
      default = "/var/cache/thoth";
      description = "Writable cache directory exposed as XDG_CACHE_HOME.";
    };

    workspace = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Agent workspace. Null uses home.";
    };

    agentDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Prime Agent resource and auth directory. Null uses home/.prime/agent.";
    };

    readWritePaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional absolute paths writable by the gateway and its descendants.";
    };

    extraPackages = mkOption {
      type = types.listOf (types.oneOf [ types.path types.package ]);
      default = [ ];
      description = "Extra tools available to the gateway, Python skills, and child processes.";
    };

    pythonPackage = mkOption {
      type = types.package;
      default = pythonEnv;
      description = "Python environment for the bundled Python skills.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Non-secret environment variables passed to the gateway.";
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Protected systemd EnvironmentFile paths for Discord and provider credentials.";
    };

    hindsight = {
      url = mkOption {
        type = types.str;
        default = "http://127.0.0.1:8888";
        description = "External Hindsight API URL used by Prime Memory.";
      };

      bankId = mkOption {
        type = types.str;
        default = "prime-memory";
        description = "Hindsight bank ID used by Prime Memory.";
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Protected file containing the optional Hindsight API key and auth scheme.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !cfg.enable || resolvedPackage != null;
        message = ''
          services.thoth.enable requires services.thoth.package, or all of
          services.thoth.source, npmDepsHash, and primeAgentPackage. The private
          Prime Agent source is not silently read from /home/oracle/prime-agent-aio.
        '';
      }
      {
        assertion = !cfg.enable || lib.hasPrefix "/" cfg.home;
        message = "services.thoth.home must be an absolute path.";
      }
      {
        assertion = !cfg.enable || lib.hasPrefix "/" cfg.statePath;
        message = "services.thoth.statePath must be an absolute path.";
      }
      {
        assertion = !cfg.enable || lib.hasPrefix "/" cfg.cachePath;
        message = "services.thoth.cachePath must be an absolute path.";
      }
    ];

    users.users.${cfg.user} = mkIf (cfg.enable && cfg.createUser) userOptions;
    users.groups.${cfg.group} = mkIf (cfg.enable && cfg.createUser) { };

    systemd.services.thoth = mkIf cfg.enable {
      description = "Thoth Prime Agent Discord gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # This is the only Thoth unit. The gateway owns schedulers, webhooks,
      # monitors, curator launches, browser/tool children, and worker processes.
      path = [
        resolvedPackage
        cfg.pythonPackage
        pkgs.nodejs_22
        pkgs.uv
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        pkgs.git
        pkgs.jq
        pkgs.openssh
        pkgs.ripgrep
        pkgs.tailscale
      ] ++ cfg.extraPackages;

      environment = {
        HOME = cfg.home;
        AGENT_WORKSPACE = workspace;
        BOT_DATA_DIR = cfg.statePath;
        PRIME_AGENT_CODING_AGENT_DIR = agentDir;
        PRIME_AGENT_DIR = agentDir;
        XDG_CACHE_HOME = cfg.cachePath;
        PRIME_MEMORY_HINDSIGHT_URL = cfg.hindsight.url;
        PRIME_MEMORY_HINDSIGHT_BANK_ID = cfg.hindsight.bankId;
        PYTHONPATH = lib.concatStringsSep ":" (map (skill: "${resolvedPackage}/share/thoth/agent/skills/${skill}/src") [
          "browser"
          "tailscale-serve"
          "vault-memory"
          "websearch"
        ]);
      } // cfg.environment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = workspace;
        ExecStartPre = pkgs.writeShellScript "thoth-prepare" ''
          set -eu
          install -d -m 0700 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} ${lib.escapeShellArg cfg.home}
          install -d -m 0700 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} ${lib.escapeShellArg cfg.statePath}
          install -d -m 0700 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} ${lib.escapeShellArg cfg.cachePath}
          install -d -m 0700 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} ${lib.escapeShellArg workspace}
          install -d -m 0700 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} ${lib.escapeShellArg agentDir}/extensions
          install -d -m 0700 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} ${lib.escapeShellArg agentDir}/skills
          ${resourceLinkScript}
        '';
        ExecStart = "${resolvedPackage}/bin/thoth";
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStopSec = "90s";
        KillSignal = "SIGTERM";
        FinalKillSignal = "SIGKILL";
        SendSIGKILL = true;
        KillMode = "control-group";
        UMask = "0077";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.home cfg.statePath cfg.cachePath workspace agentDir ] ++ cfg.readWritePaths;
        EnvironmentFile = environmentFiles;
      };
    };
  };
}
