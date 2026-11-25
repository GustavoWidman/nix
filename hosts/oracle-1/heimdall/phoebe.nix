{
  unit = "heimdall.service";
  # the web app is upstreamer's files; /api is heimdall itself
  probes = [
    {
      kind = "http";
      target = "https://heimdall.r3dlust.com/api/health";
    }
  ];
}
