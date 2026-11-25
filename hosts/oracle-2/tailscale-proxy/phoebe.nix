# upstreamer's routes, with no unit of their own. /key goes through to
# tailscale's coordination server, where /health would stop at upstreamer
{
  probes = [
    {
      kind = "http";
      target = "https://tailscale.r3dlust.com/key";
    }
  ];
}
