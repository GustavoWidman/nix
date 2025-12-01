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
    mapAttrsToList
    hasSuffix
    ;
  inherit (lib.filesystem)
    listFilesRecursive
    ;

  sshAgeFiles = listFilesRecursive ./ssh |> filter (p: hasSuffix ".age" (toString p));

  hmUsers =
    config.home-manager.users
    |> mapAttrsToList (
      userName: userConfig: {
        name = userName;
        home = userConfig.home.homeDirectory;
      }
    );

  mkSystemSshSecret = ageFile: user: {
    name =
      let
        baseName =
          ageFile
          |> toString
          |> removePrefix "${toString ./ssh}/"
          |> removeSuffix ".age"
          |> replaceStrings [ "/" ] [ "-" ];
      in
      if user.name == config.mainUser then
        "ssh-${baseName}" # Original name for compatibility
      else
        "ssh-${user.name}-${baseName}";

    value = {
      file = ageFile;
      path = "${user.home}/.ssh/${removeSuffix ".age" (removePrefix "${toString ./ssh}/" (toString ageFile))}";
      owner = user.name;
      mode = "0400";
      symlink = true;
    };
  };

  controlPath = "~/.ssh/control";
in
{
  secrets =
    sshAgeFiles
    |> map (ageFile: map (user: mkSystemSshSecret ageFile user) hmUsers)
    |> lib.flatten
    |> listToAttrs;

  home-manager.sharedModules = [
    (
      { config, ... }:
      {
        home.activation.createControlPath = {
          after = [ "writeBoundary" ];
          before = [ ];
          data = "mkdir --parents ${controlPath}";
        };

        programs.ssh = enabled {
          enableDefaultConfig = false;

          includes =
            let
              sshConfigFiles =
                sshAgeFiles
                |> filter (p: hasSuffix "config.age" (toString p))
                |> map (
                  p:
                  let
                    relativePath = removeSuffix ".age" (removePrefix "${toString ./ssh}/" (toString p));
                  in
                  "${config.home.homeDirectory}/.ssh/${relativePath}"
                );
            in
            sshConfigFiles;

          matchBlocks = {
            "*" = {
              setEnv.COLORTERM = "truecolor";
              setEnv.TERM = "xterm-256color";

              forwardAgent = false;
              compression = false;
              addKeysToAgent = "no";
              userKnownHostsFile = "~/.ssh/known_hosts";
              hashKnownHosts = false;

              controlMaster = "auto";
              controlPath = "${controlPath}/%r@%n:%p";
              controlPersist = "60m";

              serverAliveCountMax = 2;
              serverAliveInterval = 60;
            };
          };
        };
      }
    )
  ];
}
