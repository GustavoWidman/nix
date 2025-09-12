let
  keys = {
    home-vm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhOFxXLG0mwiEQb9L8JcJpA6YL2Io2ACxst4ZutR3cS root@nixos";
    oracle-2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/dj27jlY8FgNflMPk91Wza8M/Gjm+2c4A2hopshHl5 root@nixos";
    lab = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDAYlV/keQmXqAEVP+2ozD3ILSpySY6EUAD3dMqU5Bk root@nixos";
    laptop-mac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJe8nXcNoSbs+MGuN6HxXP8bw4kXGkjH0K2CA7tR+Ul";
  };
in
keys
// {
  admins = [
    keys.laptop-mac
  ];
  linux = [
    keys.lab
    keys.home-vm
    keys.oracle-2
  ];
  dev = [
    keys.home-vm
    keys.laptop-mac
  ];
  server = [
    keys.oracle-2
    keys.lab
  ];
  darwin = [
    keys.laptop-mac
  ];
  all = builtins.attrValues keys;
}
