{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    geminicommit
  ];

  secrets.geminicommit-config = {
    file = ./config.toml.age;
    path = "${config.homeDir}/${
      if config.isDarwin then "Library/Application Support/geminicommit" else ".config/geminicommit"
    }/config.toml";
    owner = config.mainUser;
    symlink = true;
  };
}
