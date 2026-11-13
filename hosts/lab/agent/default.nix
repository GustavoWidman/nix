{ config, pkgs, ... }:
let
  uid = toString config.users.users.agent.uid;
  gid = toString config.users.groups.agent.gid;
  dataDir = "/mnt/encrypted/agent/cua";
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
