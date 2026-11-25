{
  lib,
  portfolio,
  ...
}:

let
  inherit (lib)
    concatMap
    genAttrs
    mergeAttrsList
    removePrefix
    ;

  domains = [
    "guswid.com"
    "r3dlust.com"
  ];
in
{
  imports = [ portfolio.nixosModules.default ];

  # Static files, routed by the fragments the package generates, which also
  # set the security headers.
  services.portfolio = {
    enable = true;
    proxy = "upstreamer";
    domains = concatMap (d: [
      d
      "www.${d}"
    ]) domains;
    blogDomains = map (d: "blog.${d}") domains;
  };

  cloudflare.dns = mergeAttrsList (
    map (domain: {
      ${domain}.a.proxied = true;
      "blog.${domain}".a.proxied = true;
      "www.${domain}".cname = {
        target = domain;
        proxied = true;
      };
    }) domains
  );

  # Every host uses the certificate of its registrable domain, which then
  # covers its www. and blog. names.
  services.upstreamer.virtualHosts =
    genAttrs
      (concatMap (d: [
        "www.${d}"
        "blog.${d}"
      ]) domains)
      (host: {
        tls.acmeCert = removePrefix "blog." (removePrefix "www." host);
      });
}
