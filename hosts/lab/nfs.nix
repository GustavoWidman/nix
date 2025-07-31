{ ... }:

{
  services.nfs.server = {
    enable = true;

    # NFS exports configuration
    exports = ''
      /mnt/encrypted *(rw,sync,no_subtree_check,no_root_squash)
    '';
    # More secure: export only to specific network
    # /mnt/encrypted 192.168.1.0/24(rw,sync,no_subtree_check)

    # Export with specific options for performance
    # /mnt/encrypted *(rw,async,no_subtree_check,no_root_squash,wsize=1048576,rsize=1048576)

    # createMountPoints = true;
  };

  # Open firewall ports for NFS
  # networking.firewall = {
  #   allowedTCPPorts = [
  #     111
  #     2049
  #     4000
  #     4001
  #     4002
  #   ];
  #   allowedUDPPorts = [
  #     111
  #     2049
  #     4000
  #     4001
  #     4002
  #   ];

  systemd.tmpfiles.rules = [
    "Z /mnt/encrypted 0755 root root - -"
  ];
}
