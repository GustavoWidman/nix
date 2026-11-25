{
  unit = "rustfs.service";
  # the binary cache's storage, reached over the tailnet
  probes = [
    {
      kind = "http";
      target = "http://lab.tail4a3ea.ts.net:9000/health";
    }
  ];
}
