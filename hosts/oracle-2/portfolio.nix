{
  config,
  lib,
  portfolio,
  ...
}:

let
  inherit (lib)
    concatMap
    genAttrs
    removePrefix
    ;

  domains = [
    "guswid.com"
    "r3dlust.com"
  ];

  mkCertConfig = domain: {
    enable = true;
    group = "caddy-certs";
    extraDomainNames = [
      "www.${domain}"
      "blog.${domain}"
    ];
    users = [ "caddy" ];
  };

  # Every host uses the certificate of its registrable domain.
  tlsFor =
    host: config.networking.certificates."${removePrefix "blog." (removePrefix "www." host)}".paths.caddy;
in
{
  imports = [ portfolio.nixosModules.default ];

  # Static files served by Caddy from the package's generated snippet, which
  # also sets the security headers.
  services.portfolio = {
    enable = true;
    domains = concatMap (d: [
      d
      "www.${d}"
    ]) domains;
    blogDomains = map (d: "blog.${d}") domains;
  };

  networking.certificates = genAttrs domains mkCertConfig;

  services.caddy.virtualHosts =
    genAttrs
      (concatMap (d: [
        d
        "www.${d}"
        "blog.${d}"
      ]) domains)
      (host: {
        extraConfig = tlsFor host;
      });
}
