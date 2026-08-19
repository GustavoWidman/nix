{
  services.ollama = {
    enable = true;
    host = "0.0.0.0";

    loadModels = [
      "qllama/bge-small-en-v1.5"
    ];

    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "30s";
    };
  };

  networking.firewall.interfaces.honcho0.allowedTCPPorts = [
    11434
  ];
}
