{
  unit = "niks3.service";
  # a read through niks3, which keeps its objects in lab's rustfs
  probes = [
    {
      kind = "http";
      target = "https://cache.r3dlust.com/nix-cache-info";
    }
  ];
}
