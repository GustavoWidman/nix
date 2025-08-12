{
  config,
  pkgs,
  naersk,
  ...
}:
let
  naerskLib = pkgs.callPackage naersk { };
  aic = naerskLib.buildPackage {
    src = pkgs.fetchFromGitHub {
      owner = "shenxiangzhuang";
      repo = "aic";
      rev = "23fa2c2608cc30a9179718944049967118d01aef";
      sha256 = "sha256-SpQblp/F0B523Y2MLDf1uyaX5snxVinZEmb+Gc8CnCU=";
    };
    doCheck = false;
    buildInputs = with pkgs; [
      openssl
    ];
    nativeBuildInputs = with pkgs; [
      pkg-config
    ];
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
