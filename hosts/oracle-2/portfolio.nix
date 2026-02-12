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

  commonHeaders = ''
    header {
      X-Content-Type-Options nosniff
      X-Frame-Options SAMEORIGIN
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
  '';

  mkCertConfig = domain: {
    enable = true;
    group = "caddy-certs";
    extraDomainNames = [
      "www.${domain}"
      "blog.${domain}"
    ];
    users = [ "caddy" ];
    reloadServices = [ "caddy.service" ];
  };

  mkMainConfig = domain: {
    extraConfig = ''
      ${config.networking.certificates."${domain}".paths.caddy}

      handle {
        root * ${portfolio.packages.${config.metadata.architecture}.default}

        ${commonHeaders}

        try_files {path} {path}/index.html /index.html

        file_server
      }
    '';
  };

  mkBlogConfig = domain: {
    extraConfig = ''
      ${config.networking.certificates."${domain}".paths.caddy}

      handle {
        root * ${portfolio.packages.${config.metadata.architecture}.default}

        ${commonHeaders}

        handle / {
           rewrite * /blog/index.html
           file_server
        }
        handle {
           try_files {path} {path}/index.html /index.html
        }

        file_server
      }
    '';
  };

in
{
  networking.certificates = genAttrs domains mkCertConfig;

  services.caddy.virtualHosts =
    let
      # Generate main domain configs
      mainConfigs = genAttrs domains (d: mkMainConfig d);

      # Generate www configs (same as main)
      wwwConfigs = genAttrs (map (d: "www.${d}") domains) (
        host:
        let
          domain = lib.removePrefix "www." host;
        in
        mkMainConfig domain
      );
      # Generate blog configs (specialized)
      blogConfigs = genAttrs (map (d: "blog.${d}") domains) (
        host:
        let
          domain = lib.removePrefix "blog." host;
        in
        mkBlogConfig domain
      );
    in
    mainConfigs // wwwConfigs // blogConfigs;
}
