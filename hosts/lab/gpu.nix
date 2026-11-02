{ pkgs, ... }:

{
  # Cezanne passthrough needs the green_sardine firmware in the guest.
  hardware.firmware = [ pkgs.linux-firmware ];
  hardware.graphics.enable = true;

  users.users.r3dlust.extraGroups = [
    "video"
    "render"
  ];
}
