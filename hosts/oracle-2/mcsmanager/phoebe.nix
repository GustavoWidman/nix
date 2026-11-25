{
  unit = "arion-mcsmanager.service";
  # the panel; a minecraft server's port answers only while it runs
  probes = [
    {
      kind = "http";
      target = "https://minecraft.r3dlust.com";
    }
  ];
}
