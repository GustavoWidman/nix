let
  keys = {
    desktop-nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJEhKl6wG2mU+3lEm1b7WjXMX/QicjkzWGZPnd2F6+VX root@nixos";
    oracle-xray = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILa5bzp16gMJGQtRt1WnCHX24KwPTS05W88VkMRg4zsL";
    home-vm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhOFxXLG0mwiEQb9L8JcJpA6YL2Io2ACxst4ZutR3cS root@nixos";
    oracle-2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/dj27jlY8FgNflMPk91Wza8M/Gjm+2c4A2hopshHl5 root@nixos";
    lab = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDAYlV/keQmXqAEVP+2ozD3ILSpySY6EUAD3dMqU5Bk root@nixos";
    laptop-mac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJe8nXcNoSbs+MGuN6HxXP8bw4kXGkjH0K2CA7tR+Ul";
  };
in
keys
// {
  admins = [
    keys.desktop-nixos
    keys.laptop-mac
  ];
  linux = [
    keys.desktop-nixos
    keys.oracle-xray
    keys.lab
    keys.home-vm
    keys.oracle-2
  ];
  dev = [
    keys.desktop-nixos
    keys.home-vm
    keys.laptop-mac
  ];
  server = [
    keys.oracle-xray
    keys.oracle-2
    keys.lab
  ];
  darwin = [
    keys.laptop-mac
  ];
  all = builtins.attrValues keys;
}
