{
  unit = "nfs-server.service";
  # oracle-2's copyparty mounts it over the tailnet
  probes = [
    {
      kind = "tcp";
      target = "lab.tail4a3ea.ts.net:2049";
    }
  ];
}
