{ config, ... }:

{
  services.nfs.server = {
    enable = true;

    exports = ''
      /mnt/encrypted *(rw,sync,no_subtree_check,all_squash,anonuid=0,anongid=0)
      /mnt/encrypted/oracle *(rw,sync,no_subtree_check,all_squash,anonuid=${toString config.users.users.oracle.uid},anongid=${toString config.users.groups.oracle.gid})
      /mnt/encrypted/oracle/kache *(rw,sync,no_subtree_check,all_squash,anonuid=${toString config.users.users.oracle.uid},anongid=${toString config.users.groups.kache.gid})
    '';

    # createMountPoints = true;
  };

  systemd.tmpfiles.rules = [
    "d /mnt/encrypted 0755 root root - -"
  ];
}
