{ pkgs, ... }:
{
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.limine = {
    enable = true;
    secureBoot.enable = true;
    maxGenerations = 3;
    extraEntries = ''
      /Windows 11
        protocol: efi
        path: guid(fbfb5c96-139b-4c26-bc0a-ba3dd4de4ab2):/EFI/Microsoft/Boot/bootmgfw.efi
      /memtest86
        protocol: efi
        path: boot():/limine/efi/memtest86/memtest86.efi
    '';
    additionalFiles = {
      "efi/memtest86/memtest86.efi" = "${pkgs.memtest86-efi}/BOOTX64.efi";
    };
    style = {
      wallpapers = [ ];
      interface = {
        resolution = "1920x1080";
        helpHidden = true;
        branding = "r3dlust's workstation";
        brandingColor = 6;
      };
    };
  };
}
