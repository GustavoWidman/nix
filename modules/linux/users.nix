{
  config,
  pkgs,
  keys,
  ...
}:
let
  nu-smart = pkgs.writeShellScriptBin "nu-smart" ''
    if [ $# -gt 0 ]; then
      if [ "$1" = "-c" ]; then
        shift
        exec ${pkgs.bash}/bin/sh -c "$*"
      else
        exec ${pkgs.bash}/bin/sh -c "$*"
      fi
    else
      exec ${pkgs.nushell}/bin/nu -l
    fi
  '';
in
{
  users.mutableUsers = false;

  environment.shells = [ "${nu-smart}/bin/nu-smart" ];

  users.users = {
    root = {
      hashedPasswordFile = config.secrets.password.path;
      openssh.authorizedKeys.keys = keys.admins;
      shell = "${nu-smart}/bin/nu-smart";
    };

    r3dlust = {
      hashedPasswordFile = config.secrets.password.path;
      shell = "${nu-smart}/bin/nu-smart";
      name = "r3dlust";
      home = "/home/r3dlust";
      isMainUser = true;
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "docker"
      ];
    };

    build = {
      hashedPasswordFile = config.secrets.password.path;
      authorizedKey = config.secrets.ssh-misc-build.path;
      home = "/var/lib/build";
      isNormalUser = true;
      extraGroups = [ "build" ];
    };
  };
}
