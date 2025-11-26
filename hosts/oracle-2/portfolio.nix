{
  portfolio,
  config,
  lib,
  ...
}:

let
  inherit (lib)
    genAttrs
    ;
in
{
  networking.certificates."r3dlust.com" = {
    enable = true;
    group = "caddy-certs";
    extraDomainNames = [
      "www.r3dlust.com"
    ];
    users = [
      "caddy"
    ];

    reloadServices = [
      "caddy.service"
    ];
  };

  services.caddy.virtualHosts = genAttrs [ "www.r3dlust.com" "r3dlust.com" ] (_: {
    extraConfig = ''
      ${config.networking.certificates."r3dlust.com".paths.caddy}

      handle {
        root * ${portfolio.packages.${config.metadata.architecture}.default}
        try_files {path} /index.html

        header {
          X-Content-Type-Options nosniff
          X-Frame-Options DENY
          X-XSS-Protection "1; mode=block"
          Referrer-Policy strict-origin-when-cross-origin
        }

        # Cache static assets
        @static {
          path *.js *.css *.woff *.woff2 *.ttf *.otf *.png *.jpg *.jpeg *.gif *.svg *.ico
        }
        header @static Cache-Control "public, max-age=31536000, immutable"

        # Don't cache HTML files
        @html {
          path *.html /
        }
        header @html Cache-Control "no-cache, no-store, must-revalidate"

        file_server
      }
    '';
  });
}
