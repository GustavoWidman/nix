{
  ...
}:

{
  boot.initrd = {
    luks = {
      mitigateDMAAttacks = true;

      devices = {
        cryptdata = {
          device = "/dev/disk/by-label/encrypted";

          keyFile = "/dev/disk/by-id/usb-Generic_Flash-Disk_0111214634-0:0";
          keyFileSize = 4096;

          preLVM = true;
        };
      };
    };
  };

  fileSystems."/mnt/encrypted" = {
    device = "/dev/disk/by-id/dm-name-cryptdata";
    fsType = "xfs";
    options = [
      "noatime"
      "nodiratime"
      "logbufs=8"
      "logbsize=256k"
      "largeio"
      "inode64"
    ];
  };
}
