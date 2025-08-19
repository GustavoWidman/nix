{
  config,
  lib,
  modulesPath,
  ...
}:
let
  inherit (lib) enabled;
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader = {
    systemd-boot = enabled {
      editor = false;
    };

    efi.canTouchEfiVariables = true;
  };

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "xen_blkfront"
    "vmw_pvscsi"
  ];
  boot.initrd.kernelModules = [
    "nvme"
  ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/sda3"; # todo swap to label
    fsType = "xfs";
    options = [ "noatime" ];
  };

  fileSystems.${config.boot.loader.efi.efiSysMountPoint} = {
    device = "/dev/disk/by-uuid/2B75-2AD5"; # todo swap to label
    fsType = "vfat";
    options = [ "noatime" ];
  };

  swapDevices = [
    {
      device = "/dev/sda2"; # todo swap to label
    }
  ];
}
