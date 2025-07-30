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

  # boot.initrd.availableKernelModules = [
  #   "ata_piix"
  #   "uhci_hcd"
  #   "virtio_pci"
  #   "virtio_scsi"
  #   "xhci_pci"
  #   "usb_storage"
  #   "sd_mod"
  #   "sr_mod"
  # ];
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "usbhid"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/root";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems.${config.boot.loader.efi.efiSysMountPoint} = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "noatime" ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-label/swap";
    }
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
}
