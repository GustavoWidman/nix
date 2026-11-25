{
  unit = "copyparty.service";
  probes = [
    {
      kind = "http";
      target = "https://files.r3dlust.com";
    }
  ];
}
