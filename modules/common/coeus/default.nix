{ config, lib, ... }:
{
  # root's coeusd and the main user's CLI both read it
  secrets.coeus-key = {
    file = ./key.age;
    owner = config.mainUser;
    mode = "400";
  };

  services.coeus = {
    enable = true;
    keyFile = config.secrets.coeus-key.path;
    flake = "git+https://github.com/GustavoWidman/nix";
    follow = {
      ref = "deployed";
      interval = "15m";
    };
    hosts = lib.coeusHosts;
  };

  # git rewrites github https urls to ssh, so root's coeusd fetches the fleet's
  # flake over ssh and has to know github's host key without asking
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
}
