{
  unit = "tailscale-derper.service";
  probes = [
    {
      kind = "http";
      target = "https://derp.r3dlust.com";
    }
  ];
}
