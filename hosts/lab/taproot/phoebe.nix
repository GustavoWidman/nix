{
  unit = "taproot.service";
  probes = [
    {
      kind = "http";
      target = "https://lab.tail4a3ea.ts.net:8317/healthz";
    }
  ];
}
