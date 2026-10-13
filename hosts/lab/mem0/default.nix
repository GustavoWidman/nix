{ config, lib, pkgs, ... }:
let
  apiPort = 8888;
  dashboardPort = 3000;
  source = pkgs.fetchFromGitHub {
    owner = "mem0ai";
    repo = "mem0";
    rev = "94c3fe9f238f3dbf29c9ce98643bd71eb13077cd";
    hash = "sha256-C7E7Xd1+7Vy0ZwRIjblihexQTkS2YBPx5Sogz6ACYXs=";
  };
  dataDir = "/mnt/encrypted/mem0";
  environmentFile = config.secrets.mem0-environment.path;
  composeFile = pkgs.writeText "mem0-compose.yaml" ''
    name: mem0
    services:
      postgres:
        image: pgvector/pgvector:pg17
        restart: unless-stopped
        shm_size: 128mb
        environment:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: "''${POSTGRES_PASSWORD:?set POSTGRES_PASSWORD in the agenix environment file}"
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -q -d postgres -U postgres"]
          interval: 5s
          timeout: 5s
          retries: 5
        volumes:
          - ${dataDir}/postgres:/var/lib/postgresql/data
          - ${source}/server/init-db.sh:/docker-entrypoint-initdb.d/init-db.sh:ro
        networks: [mem0]

      api:
        build:
          context: ${source}/server
          dockerfile: Dockerfile
        restart: unless-stopped
        env_file: [${environmentFile}]
        environment:
          POSTGRES_HOST: postgres
          POSTGRES_PORT: "5432"
          POSTGRES_DB: postgres
          POSTGRES_USER: postgres
          POSTGRES_COLLECTION_NAME: memories
          APP_DB_NAME: mem0_app
          DASHBOARD_URL: http://lab.tail4a3ea.ts.net:${toString dashboardPort}
          MEM0_TELEMETRY: "false"
          HISTORY_DB_PATH: /app/history/history.db
          PYTHONUNBUFFERED: "1"
        command: ["sh", "-c", "alembic upgrade head && uvicorn main:app --host 0.0.0.0 --port 8000"]
        ports:
          - "${toString apiPort}:8000"
        volumes:
          - ${dataDir}/history:/app/history
        depends_on:
          postgres:
            condition: service_healthy
        healthcheck:
          test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=3)"]
          interval: 10s
          timeout: 5s
          retries: 5
        extra_hosts:
          - "host.docker.internal:host-gateway"
        networks: [mem0]

      dashboard:
        build:
          context: ${source}/server/dashboard
          dockerfile: Dockerfile
        restart: unless-stopped
        environment:
          NEXT_PUBLIC_API_URL: http://lab.tail4a3ea.ts.net:${toString apiPort}
          API_INTERNAL_URL: http://api:8000
          NEXT_PUBLIC_INSTANCE_NAME: Mem0 Lab
        ports:
          - "${toString dashboardPort}:3000"
        depends_on:
          api:
            condition: service_healthy
        healthcheck:
          test: ["CMD", "wget", "-qO-", "http://127.0.0.1:3000/api/health"]
          interval: 10s
          timeout: 5s
          retries: 3
        networks: [mem0]

    networks:
      mem0:
        name: mem0
        driver: bridge
        driver_opts:
          com.docker.network.bridge.name: mem00
  '';
  compose = pkgs.writeShellApplication {
    name = "mem0-compose";
    runtimeInputs = [ pkgs.docker pkgs.coreutils ];
    text = ''
      exec docker compose --env-file ${environmentFile} --project-name mem0 --file ${composeFile} "$@"
    '';
  };
  firewallStart = pkgs.writeShellScript "mem0-firewall-start" ''
    ${pkgs.iptables}/bin/iptables -C DOCKER-USER ! -i tailscale0 -p tcp --dport ${toString apiPort} -j DROP 2>/dev/null \
      || ${pkgs.iptables}/bin/iptables -I DOCKER-USER 1 ! -i tailscale0 -p tcp --dport ${toString apiPort} -j DROP
    ${pkgs.iptables}/bin/iptables -C DOCKER-USER ! -i tailscale0 -p tcp --dport ${toString dashboardPort} -j DROP 2>/dev/null \
      || ${pkgs.iptables}/bin/iptables -I DOCKER-USER 1 ! -i tailscale0 -p tcp --dport ${toString dashboardPort} -j DROP
  '';
  firewallStop = pkgs.writeShellScript "mem0-firewall-stop" ''
    ${pkgs.iptables}/bin/iptables -D DOCKER-USER ! -i tailscale0 -p tcp --dport ${toString apiPort} -j DROP 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -D DOCKER-USER ! -i tailscale0 -p tcp --dport ${toString dashboardPort} -j DROP 2>/dev/null || true
  '';
in
{
  config = lib.mkIf (builtins.pathExists ./environment.env.age) {
    secrets.mem0-environment = {
      file = ./environment.env.age;
      mode = "0400";
    };

    systemd.tmpfiles.settings."10-mem0" = {
      ${dataDir}.d = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${dataDir}/postgres".d = {
        mode = "0700";
        user = "999";
        group = "999";
      };
      "${dataDir}/history".d = {
        mode = "0700";
        user = "root";
        group = "root";
      };
    };

    systemd.services.mem0-firewall = {
      description = "Restrict Mem0 ports to Tailscale";
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      after = [ "docker.service" ];
      before = [ "mem0-stack.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = firewallStart;
        ExecStop = firewallStop;
      };
    };

    systemd.services.mem0-stack = {
      description = "Mem0 self-hosted memory API and dashboard";
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" "mem0-firewall.service" ];
      after = [ "docker.service" "mem0-firewall.service" "systemd-tmpfiles-setup.service" ];
      unitConfig.RequiresMountsFor = dataDir;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
        ExecStartPre = "${pkgs.util-linux}/bin/mountpoint --quiet /mnt/encrypted";
        ExecStart = "${compose}/bin/mem0-compose up --detach --build";
        ExecStop = "${compose}/bin/mem0-compose down";
        TimeoutStartSec = "45min";
        TimeoutStopSec = 120;
      };
    };

    systemd.services.mem0-prune-request-logs = {
      description = "Prune Mem0 request logs older than 30 days";
      requires = [ "mem0-stack.service" ];
      after = [ "mem0-stack.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${compose}/bin/mem0-compose exec --no-TTY postgres psql -U postgres -d mem0_app -c \"DELETE FROM request_logs WHERE created_at < NOW() - INTERVAL '30 days';\"";
      };
    };

    systemd.timers.mem0-prune-request-logs = {
      description = "Weekly cleanup of old Mem0 request logs";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ apiPort dashboardPort ];
    networking.firewall.interfaces.mem00.allowedTCPPorts = [
      11434
      config.services.cliproxyapi.port
    ];
  };
}
