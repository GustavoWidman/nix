{
  config,
  pkgs,
  keys,
  ...
}:

{
  users.mutableUsers = false;

  users.users = {
    root = {
      hashedPasswordFile = config.secrets.password.path;
      openssh.authorizedKeys.keys = keys.admins;
      shell = pkgs.nushell;
    };

    r3dlust = {
      hashedPasswordFile = config.secrets.password.path;
      shell = pkgs.nushell;
      name = "r3dlust";
      home = "/home/r3dlust";
      isMainUser = true;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    build = {
      hashedPasswordFile = config.secrets.password.path;
      openssh.authorizedKeys.keys = keys.all;
      home = "/var/lib/build";
      isNormalUser = true;
      extraGroups = [ "build" ];
    };
  };
}
