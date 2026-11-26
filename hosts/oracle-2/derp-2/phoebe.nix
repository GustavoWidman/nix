{
  unit = "tailscale-derper.service";
  probes = [
    {
      kind = "http";
      target = "https://derp-2.r3dlust.com";
    }
  ];
}
