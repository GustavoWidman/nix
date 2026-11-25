{
  unit = "podman-teamspeak6.service";
  # voice is udp, which no probe speaks; file transfer shares its address
  probes = [
    {
      kind = "tcp";
      target = "rockyclan.com:30033";
    }
  ];
}
