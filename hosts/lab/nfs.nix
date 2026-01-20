{ ... }:

{
  services.nfs.server = {
    enable = true;

    exports = ''
      /mnt/encrypted *(rw,sync,no_subtree_check,all_squash,anonuid=0,anongid=0)
    '';

    # createMountPoints = true;
  };

  systemd.tmpfiles.rules = [
    "Z /mnt/encrypted 0755 root root - -"
  ];
}
