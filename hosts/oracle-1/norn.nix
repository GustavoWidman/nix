{
  services.norn = {
    enable = true;
    mode = "adopt";
  };

  cloudflare = {
    address.ipv4 = "144.22.180.239";

    dns = {
      "rockyclan.com".a.addresses = [ "164.152.51.27" ];
      "www.rockyclan.com".cname = {
        target = "rockyclan.com";
        proxied = true;
      };
    };
  };
}
