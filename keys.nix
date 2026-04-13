let
  keys = {
    desktop-nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJEhKl6wG2mU+3lEm1b7WjXMX/QicjkzWGZPnd2F6+VX root@nixos";
    oracle-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB5b0huhIgxXA2toMoeZg7wslf9r3izay7ROC3Q3Fixk root@nixos";
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
    keys.lab
  ];
  linux = [
    keys.desktop-nixos
    keys.lab
    keys.oracle-1
    keys.oracle-2
  ];
  dev = [
    keys.desktop-nixos
    keys.laptop-mac
  ];
  server = [
    keys.oracle-1
    keys.oracle-2
    keys.lab
  ];
  darwin = [
    keys.laptop-mac
  ];
  all = builtins.attrValues keys;
}
