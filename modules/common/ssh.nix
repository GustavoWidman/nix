{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    enabled
    listToAttrs
    filter
    removePrefix
    removeSuffix
    replaceStrings
    hasSuffix
    ;
  inherit (lib.filesystem)
    listFilesRecursive
    ;

  mkSshSecret = ageFile: {
    name =
      ageFile
      |> toString
      |> removePrefix "${toString ./ssh}/"
      |> removeSuffix ".age"
      |> replaceStrings [ "/" ] [ "-" ]
      |> (name: "ssh-${name}");

    value = {
      file = ageFile;
      path = "${config.homeDir}/.ssh/${removeSuffix ".age" (removePrefix "${toString ./ssh}/" (toString ageFile))}";
      owner = config.mainUser;
      mode = "0400";
      symlink = true;
    };
  };

  controlPath = "~/.ssh/control";
in
{
  secrets =
    (
      listFilesRecursive ./ssh
      |> filter (p: hasSuffix ".age" (toString p))
      |> filter (p: !hasSuffix "ssh/config.age" (toString p))
      |> map mkSshSecret
      |> listToAttrs
    )
    // ({
      sshConfig = {
        file = ./ssh/config.age;
        mode = "444";
      };
    });

  home-manager.sharedModules = [
    {
      home.activation.createControlPath = {
        after = [ "writeBoundary" ];
        before = [ ];
        data = "mkdir --parents ${controlPath}";
      };

      programs.ssh = enabled {
        controlMaster = "auto";
        controlPath = "${controlPath}/%r@%n:%p";
        controlPersist = "60m";
        serverAliveCountMax = 2;
        serverAliveInterval = 60;

        includes = [ config.secrets.sshConfig.path ];

        matchBlocks = {
          "*" = {
            setEnv.COLORTERM = "truecolor";
            setEnv.TERM = "xterm-256color";
          };
        };
      };
    }
  ];
}
