let
  keys = {
    lab = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDAYlV/keQmXqAEVP+2ozD3ILSpySY6EUAD3dMqU5Bk root@nixos";
    laptop-mac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBJe8nXcNoSbs+MGuN6HxXP8bw4kXGkjH0K2CA7tR+Ul";
  };
in
keys
// {
  admins = [ keys.laptop-mac ];
  linux = [ keys.lab ];
  darwin = [ keys.laptop-mac ];
  all = builtins.attrValues keys;
}
