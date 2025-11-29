{
  portfolio,
  config,
  lib,
  ...
}:

let
  inherit (lib) genAttrs concatMap;

  domains = [
    "guswid.com"
    "r3dlust.com"
  ];

  mkCertConfig = domain: {
    enable = true;
    group = "caddy-certs";
    extraDomainNames = [ "www.${domain}" ];
    users = [ "caddy" ];
    reloadServices = [ "caddy.service" ];
  };

  mkVhostConfig = domain: {
    extraConfig = ''
      ${config.networking.certificates."${domain}".paths.caddy}

      handle {
        root * ${portfolio.packages.${config.metadata.architecture}.default}
        try_files {path} /index.html

        header {
          X-Content-Type-Options nosniff
          X-Frame-Options DENY
          X-XSS-Protection "1; mode=block"
          Referrer-Policy strict-origin-when-cross-origin
        }

        @static {
          path *.js *.css *.woff *.woff2 *.ttf *.otf *.png *.jpg *.jpeg *.gif *.svg *.ico
        }
        header @static Cache-Control "public, max-age=31536000, immutable"

        @html {
          path *.html /
        }
        header @html Cache-Control "no-cache, no-store, must-revalidate"

        file_server
      }
    '';
  };

in
{
  networking.certificates = genAttrs domains mkCertConfig;

  services.caddy.virtualHosts =
    genAttrs
      (concatMap (d: [
        d
        "www.${d}"
      ]) domains)
      (
        host:
        let
          domain = if lib.hasPrefix "www." host then lib.removePrefix "www." host else host;
        in
        mkVhostConfig domain
      );
}
