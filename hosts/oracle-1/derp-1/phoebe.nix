{
  unit = "tailscale-derper.service";
  probes = [
    {
      kind = "http";
      target = "https://derp-1.r3dlust.com";
    }
  ];
}
