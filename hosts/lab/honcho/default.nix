{
  config,
  lib,
  pkgs,
  ...
}:
let
  apiPort = 8000;
  network = "honcho";
  environmentFile = config.secrets.honcho-environment.path;
  databaseEnvironmentFile = config.secrets.honcho-database-environment.path;
  databaseInit = pkgs.writeText "honcho-database-init.sql" ''
    CREATE EXTENSION IF NOT EXISTS vector;
  '';

  commonEnvironment = {
    CACHE_URL = "redis://honcho-redis:6379/0?suppress=true";
    CACHE_ENABLED = "true";
    AUTH_USE_AUTH = "true";
    EMBED_MESSAGES = "true";
    DREAM_ENABLED = "true";

    DERIVER_MODEL_CONFIG__TRANSPORT = "openai";
    DERIVER_MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DERIVER_MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    SUMMARY_MODEL_CONFIG__TRANSPORT = "openai";
    SUMMARY_MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    SUMMARY_MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    DREAM_DEDUCTION_MODEL_CONFIG__TRANSPORT = "openai";
    DREAM_DEDUCTION_MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DREAM_DEDUCTION_MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    DREAM_INDUCTION_MODEL_CONFIG__TRANSPORT = "openai";
    DREAM_INDUCTION_MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DREAM_INDUCTION_MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    DIALECTIC_LEVELS__minimal__MODEL_CONFIG__TRANSPORT = "openai";
    DIALECTIC_LEVELS__minimal__MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DIALECTIC_LEVELS__minimal__MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    DIALECTIC_LEVELS__low__MODEL_CONFIG__TRANSPORT = "openai";
    DIALECTIC_LEVELS__low__MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DIALECTIC_LEVELS__low__MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    DIALECTIC_LEVELS__medium__MODEL_CONFIG__TRANSPORT = "openai";
    DIALECTIC_LEVELS__medium__MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DIALECTIC_LEVELS__medium__MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    DIALECTIC_LEVELS__high__MODEL_CONFIG__TRANSPORT = "openai";
    DIALECTIC_LEVELS__high__MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DIALECTIC_LEVELS__high__MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";
    DIALECTIC_LEVELS__max__MODEL_CONFIG__TRANSPORT = "openai";
    DIALECTIC_LEVELS__max__MODEL_CONFIG__MODEL = "gpt-5.6-luna";
    DIALECTIC_LEVELS__max__MODEL_CONFIG__OVERRIDES__BASE_URL = "https://lab.tail4a3ea.ts.net:8317/v1";

    EMBEDDING__MODEL_CONFIG__TRANSPORT = "openai";
    EMBEDDING__MODEL_CONFIG__MODEL = "qllama/bge-small-en-v1.5";
    EMBEDDING__MODEL_CONFIG__OVERRIDES__BASE_URL = "http://172.19.0.1:11434/v1";
    EMBEDDING__VECTOR_DIMENSIONS = "384";
  };

  commonOptions = [
    "--network=${network}"
  ];

  applicationOptions = commonOptions ++ [
    "--add-host=host.docker.internal:host-gateway"
  ];

  waitForHealthy =
    containers:
    pkgs.writeShellScript "wait-for-honcho-containers" ''
      set -eu
      for container in ${toString containers}; do
        attempts=0
        until [ "$("${pkgs.docker}/bin/docker" inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null)" = healthy ]; do
          attempts=$((attempts + 1))
          if [ "$attempts" -ge 120 ]; then
            echo "$container did not become healthy" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
      done
    '';
in
{
  config =
    lib.mkIf (builtins.pathExists ./environment.env.age && builtins.pathExists ./database.env.age)
      {
        secrets = {
          honcho-environment = {
            file = ./environment.env.age;
            mode = "400";
          };
          honcho-database-environment = {
            file = ./database.env.age;
            mode = "400";
          };
        };

        virtualisation.oci-containers.backend = "docker";

        virtualisation.oci-containers.containers = {
          honcho-api = {
            image = "ghcr.io/plastic-labs/honcho:v3.0.12@sha256:8ed9a3f50269f7f18c69848f8cc9b6ed54a24fd773fbea905cafae174174fab5";
            autoStart = true;
            entrypoint = "sh";
            cmd = [ "docker/entrypoint.sh" ];
            environment = commonEnvironment;
            environmentFiles = [ environmentFile ];
            ports = [ "${toString apiPort}:8000" ];
            dependsOn = [
              "honcho-database"
              "honcho-redis"
            ];
            extraOptions = applicationOptions ++ [
              "--health-cmd=/app/.venv/bin/python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=2).read()\""
              "--health-interval=5s"
              "--health-timeout=5s"
              "--health-retries=5"
              "--health-start-period=10s"
            ];
          };

          honcho-deriver = {
            image = "ghcr.io/plastic-labs/honcho:v3.0.12@sha256:8ed9a3f50269f7f18c69848f8cc9b6ed54a24fd773fbea905cafae174174fab5";
            autoStart = true;
            entrypoint = "/app/.venv/bin/python";
            cmd = [
              "-m"
              "src.deriver"
            ];
            environment = commonEnvironment;
            environmentFiles = [ environmentFile ];
            dependsOn = [
              "honcho-api"
              "honcho-database"
              "honcho-redis"
            ];
            extraOptions = applicationOptions ++ [ "--no-healthcheck" ];
          };

          honcho-database = {
            image = "pgvector/pgvector:pg15@sha256:18d16372b8406bb38a9f94cbff15d125c463d71fde2770aa8b5c64bfcc1578ee";
            autoStart = true;
            cmd = [
              "postgres"
              "-c"
              "max_connections=200"
            ];
            environment = {
              POSTGRES_DB = "honcho";
              POSTGRES_USER = "honcho";
              PGDATA = "/var/lib/postgresql/data/pgdata";
            };
            environmentFiles = [ databaseEnvironmentFile ];
            volumes = [
              "honcho-postgres:/var/lib/postgresql/data"
              "${databaseInit}:/docker-entrypoint-initdb.d/init.sql:ro"
            ];
            extraOptions = commonOptions ++ [
              "--health-cmd=pg_isready -U honcho -d honcho"
              "--health-interval=5s"
              "--health-timeout=5s"
              "--health-retries=5"
            ];
          };

          honcho-redis = {
            image = "redis:8.2@sha256:616bb446d5db225ddf786052834279e7c7222c48694d4451e8af22b8f5953b28";
            autoStart = true;
            volumes = [ "honcho-redis:/data" ];
            extraOptions = commonOptions ++ [
              "--health-cmd=redis-cli ping"
              "--health-interval=5s"
              "--health-timeout=5s"
              "--health-retries=5"
            ];
          };
        };

        systemd.services = {
          honcho-firewall = {
            description = "Restrict Honcho API access to Tailscale";
            wantedBy = [ "multi-user.target" ];
            requires = [ "docker.service" ];
            after = [ "docker.service" ];
            before = [ "docker-honcho-api.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "honcho-firewall-start" ''
                ${pkgs.iptables}/bin/iptables -C DOCKER-USER ! -i tailscale0 -p tcp --dport ${toString apiPort} -j DROP 2>/dev/null \
                  || ${pkgs.iptables}/bin/iptables -I DOCKER-USER 1 ! -i tailscale0 -p tcp --dport ${toString apiPort} -j DROP
              '';
              ExecStop = pkgs.writeShellScript "honcho-firewall-stop" ''
                ${pkgs.iptables}/bin/iptables -D DOCKER-USER ! -i tailscale0 -p tcp --dport ${toString apiPort} -j DROP 2>/dev/null \
                  || true
              '';
            };
          };
          honcho-network = {
            description = "Honcho container network";
            wantedBy = [ "multi-user.target" ];
            requires = [ "docker.service" ];
            after = [
              "docker.service"
              "docker.socket"
            ];
            before = [
              "docker-honcho-api.service"
              "docker-honcho-database.service"
              "docker-honcho-deriver.service"
              "docker-honcho-redis.service"
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.docker}/bin/docker network inspect ${network}";
              ExecStartPre = "-${pkgs.docker}/bin/docker network create --driver bridge --opt com.docker.network.bridge.name=honcho0 ${network}";
            };
          };
          docker-honcho-api = {
            requires = [
              "honcho-firewall.service"
              "honcho-network.service"
            ];
            after = [
              "honcho-firewall.service"
              "honcho-network.service"
            ];
            serviceConfig.ExecStartPre = [
              (waitForHealthy [
                "honcho-database"
                "honcho-redis"
              ])
            ];
          };
          docker-honcho-database = {
            requires = [ "honcho-network.service" ];
            after = [ "honcho-network.service" ];
          };
          docker-honcho-deriver = {
            requires = [ "honcho-network.service" ];
            after = [ "honcho-network.service" ];
            serviceConfig.ExecStartPre = [
              (waitForHealthy [
                "honcho-api"
                "honcho-database"
                "honcho-redis"
              ])
            ];
          };
          docker-honcho-redis = {
            requires = [ "honcho-network.service" ];
            after = [ "honcho-network.service" ];
          };
        };

        networking.firewall.interfaces = {
          honcho0.allowedTCPPorts = [ config.services.cliproxyapi.port ];
          tailscale0.allowedTCPPorts = [ apiPort ];
        };
      };
}
