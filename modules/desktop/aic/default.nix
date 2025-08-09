{
  config,
  pkgs,
  ...
}:
let
  aic = pkgs.rustPlatform.buildRustPackage {
    name = "aic";
    src = pkgs.fetchFromGitHub {
      owner = "shenxiangzhuang";
      repo = "aic";
      rev = "23fa2c2608cc30a9179718944049967118d01aef";
      sha256 = "sha256-SpQblp/F0B523Y2MLDf1uyaX5snxVinZEmb+Gc8CnCU=";
    };
    doCheck = false;
    cargoHash = "sha256-K3k9FvTz9crx40Enr35YzYJXFqD3vhZyKUDOzxxAOgI=";
  };
in

{
  environment.systemPackages = [
    aic
  ];

  secrets.aic-config = {
    file = ./config.toml.age;
    path = "${config.homeDir}/.config/aic/config.toml";
    owner = config.mainUser;
    symlink = true;
  };
}
