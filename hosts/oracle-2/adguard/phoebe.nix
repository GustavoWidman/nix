{
  unit = "adguardhome.service";
  # adguard home serves no plain dns, which is all a dns probe speaks, so it
  # is asked over https instead: an A query for example.com, in base64url
  probes = [
    {
      kind = "http";
      target = "https://dns.r3dlust.com/dns-query?dns=AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE";
    }
    {
      kind = "tcp";
      target = "dns.r3dlust.com:853";
      tls = true;
    }
  ];
}
