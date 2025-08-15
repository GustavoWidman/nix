{
  config,
  pkgs,
  ...
}:
let
  ai-commit = pkgs.buildGoModule {
    name = "ai-commit";
    src = pkgs.fetchFromGitHub {
      owner = "renatogalera";
      repo = "ai-commit";
      rev = "8008363761bb0d5b4e8a87a07b5fe58df9e040ef";
      hash = "sha256-UkH93RjWW+ixb7CvlAYEwTd1jiq/jKEGRgKhWcDxd68=";
    };

    vendorHash = "sha256-a7p6JSJVRY9D2GhjXNVaHaXsy+CjhjFzMUVMbWtUiWg=";
    subPackages = [ "cmd/ai-commit" ];
  };
in
{
  environment.systemPackages = [
    ai-commit
  ];

  secrets.ai-commit-config = {
    file = ./config.yaml.age;
    path = "${config.homeDir}/.config/ai-commit/config.yaml";
    owner = config.mainUser;
    symlink = true;
  };
}
