{ config, pkgs, ... }:
let
  uid = toString config.users.users.agent.uid;
  gid = toString config.users.groups.agent.gid;
in
{
  virtualisation.docker.enable = true;

  users.users.agent = {
    uid = 1005;
    isSystemUser = true;
    group = "agent";
    home = "/home/agent";
    createHome = true;
    shell = pkgs.bash;
    linger = true;
    authorizedKey = config.secrets.ssh-main-lab.path;
  };

  users.groups.agent = {
    gid = 1005;
  };

  home-manager.users = {
    agent.home = {
      stateVersion = "26.11";
      homeDirectory = "/home/agent";
    };
  };


  virtualisation.oci-containers = {
    backend = "docker";

    containers.agent-workstation = {
      image = "lscr.io/linuxserver/webtop:ubuntu-kde";

      autoStart = true;

      ports = [
        "3001:3001"
      ];

      volumes = [
        "/home/agent/workspace:/config:rw"
        "/home/agent/services:/custom-services.d:rw"
        "/home/agent/.ssh:/config/.ssh:ro"
        "/home/agent/.ssh/known_hosts:/config/.ssh/known_hosts:rw"
        "/home/agent/.ssh/control:/config/.ssh/control:rw"
        "/mnt/encrypted/agent:/config/external:rw"
        "/nix/store:/nix/store:ro"
        "/run/agenix:/run/agenix:ro"
        "/run/agenix.d:/run/agenix.d:ro"
      ];

      environment = {
        PUID = uid;
        PGID = gid;
        TZ = "America/Sao_Paulo";
        PIXELFLUX_WAYLAND = "false";
      };

      extraOptions = [
        "--hostname=workstation"
        "--add-host=workstation:127.0.1.1"

        "--shm-size=2g"
        "--device=/dev/dri:/dev/dri"
        "--pids-limit=-1"

        "--network=host"
        "--security-opt=seccomp=unconfined"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/agent/workspace 0755 ${uid} ${gid} -"
    "d /mnt/encrypted/agent 0755 ${uid} ${gid} -"
    "f /home/agent/.ssh/known_hosts 0600 ${uid} ${gid} -"
    "d /home/agent/.ssh/control 0755 ${uid} ${gid} -"
    "d /home/agent/services 0755 ${uid} ${gid} -"
  ];
}
