{
  config,
  cliproxyapi,
  ...
}:
{
  secrets.cliproxyapi = {
    file = ./config.yaml.age;
    mode = "400"; # read-only for owner
    owner = config.services.cliproxyapi.user;
    group = config.services.cliproxyapi.user;
  };

  services.cliproxyapi = {
    enable = true;
    package = cliproxyapi.packages.${config.metadata.architecture}.cliproxyapi-plus;
    configFile = config.secrets.cliproxyapi.path;
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.cliproxyapi.port
  ];
}
