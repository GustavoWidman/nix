{ config, pkgs, ... }:
let
  uid = toString config.users.users.agent.uid;
  gid = toString config.users.groups.agent.gid;
  dataDir = "/mnt/encrypted/agent/cua";
  # runner = pkgs.writeText "agent-cua-sandbox.py" (builtins.readFile ./cua-sandbox.py);
in
{
  users.users.agent = {
    uid = 989;
    isSystemUser = true;
    group = "agent";
    extraGroups = [ "kvm" "systemd-journal" "docker" ];
    home = "/home/agent";
    createHome = true;
    shell = pkgs.bash;
    linger = true;
    authorizedKey = config.secrets.ssh-main-lab.path;
  };
  users.groups.agent.gid = 989;
  home-manager.users.agent.home = {
    stateVersion = "26.11";
    homeDirectory = "/home/agent";
  };

  # Nested KVM on PVE2 previously triggered a fatal async page fault in the
  # host kernel. Keep async page faults disabled for this nested-QEMU guest.
  boot.kernelParams = [ "no-kvmapf" ];

  environment.systemPackages = [
    pkgs.codex
    pkgs.qemu
    pkgs.uv
  ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 3001 ];

  # systemd.services.agent-cua-sandbox = {
  #   description = "Persistent CUA Omarchy sandbox for the agent workstation";
  #   wantedBy = [ "multi-user.target" ];
  #   wants = [ "network-online.target" ];
  #   after = [
  #     "network-online.target"
  #     "systemd-tmpfiles-setup.service"
  #   ];
  #   unitConfig = {
  #     RequiresMountsFor = dataDir;
  #     ConditionPathExists = "/dev/kvm";
  #   };
  #   path = [
  #     pkgs.qemu
  #     pkgs.coreutils
  #     pkgs.procps
  #     pkgs.stdenv.cc
  #     pkgs.python3Packages.websockify
  #   ];
  #   serviceConfig = {
  #     Type = "simple";
  #     User = "agent";
  #     Group = "agent";
  #     SupplementaryGroups = [ "kvm" ];
  #     WorkingDirectory = dataDir;
  #     ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0700 ${dataDir}/home ${dataDir}/uv-cache";
  #     Environment = [
  #       "HOME=${dataDir}/home"
  #       "UV_CACHE_DIR=${dataDir}/uv-cache"
  #       "C_INCLUDE_PATH=${pkgs.linuxHeaders}/include"
  #       "CFLAGS=-I${pkgs.linuxHeaders}/include"
  #       "NOVNC_WEB_DIR=${pkgs.novnc}/share/webapps/novnc"
  #       "PYTHONUNBUFFERED=1"
  #       "PYTHONDONTWRITEBYTECODE=1"
  #     ];
  #     ExecStart = "${pkgs.uv}/bin/uv run --python ${pkgs.python313}/bin/python --with cua-sandbox==0.8.0 ${runner} start";
  #     Restart = "on-failure";
  #     RestartSec = 10;
  #     TimeoutStartSec = "30min";
  #     TimeoutStopSec = 180;
  #     KillMode = "mixed";
  #     UMask = "0077";
  #   };
  # };

  systemd.tmpfiles.rules = [
    "d /home/agent/workspace 0755 ${uid} ${gid} -"
    "d /mnt/encrypted/agent 0755 ${uid} ${gid} -"
    "d ${dataDir} 0700 ${uid} ${gid} -"
    "d ${dataDir}/home 0700 ${uid} ${gid} -"
    "d ${dataDir}/uv-cache 0700 ${uid} ${gid} -"
    "f /home/agent/.ssh/known_hosts 0600 ${uid} ${gid} -"
    "d /home/agent/.ssh/control 0755 ${uid} ${gid} -"
  ];
}
