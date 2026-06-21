{ config, ... }:
{
  secrets.hindsight-environment = {
    file = ./environment.env.age;
    mode = "400";
  };

  virtualisation.oci-containers.containers.hindsight = {
    image = "ghcr.io/vectorize-io/hindsight:latest";
    autoStart = true;
    environment = {
      HINDSIGHT_API_HOST = "0.0.0.0";
      HINDSIGHT_API_PORT = "8888";
      HINDSIGHT_CP_DATAPLANE_API_URL = "http://127.0.0.1:8888";
      HOSTNAME = "0.0.0.0";
      PORT = "9999";
    };
    environmentFiles = [ config.secrets.hindsight-environment.path ];
    ports = [
      "8888:8888"
      "9999:9999"
    ];
    volumes = [
      "hindsight-data:/home/hindsight/.pg0"
    ];
    extraOptions = [ "--pull=always" ];
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    8888
    9999
  ];
}
