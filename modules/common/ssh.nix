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

  relative =
    ageFile:
    ageFile
    |> toString
    |> removePrefix "${toString ./ssh}/"
    |> removeSuffix ".age";

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
        baseName = replaceStrings [ "/" ] [ "-" ] (relative ageFile);
      in
      if user.name == config.mainUser then
        "ssh-${baseName}" # Original name for compatibility
      else
        "ssh-${user.name}-${baseName}";

    value = {
      file = ageFile;
      path = "${user.home}/.ssh/${relative ageFile}";
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
            sshAgeFiles |> filter (p: hasSuffix "config.age" (toString p)) |> map (p: "~/.ssh/${relative p}");

          settings."*" = {
            SetEnv = {
              COLORTERM = "truecolor";
              TERM = "xterm-256color";
            };

            ForwardAgent = false;
            Compression = false;
            AddKeysToAgent = "no";
            UserKnownHostsFile = "~/.ssh/known_hosts";
            HashKnownHosts = false;

            ControlMaster = "auto";
            ControlPath = "${controlPath}/%r@%n:%p";
            ControlPersist = "60m";

            ServerAliveCountMax = 2;
            ServerAliveInterval = 60;
          };
        };
      }
    )
  ];
}
