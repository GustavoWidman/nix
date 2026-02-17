{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    genAttrs
    enabled
    ;

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

  mkReverseProxyConfig = domain: {
    extraConfig = ''
      ${config.networking.certificates."${domain}".paths.caddy}

      ${commonHeaders}

      reverse_proxy http://127.0.0.1:${toString config.services.portfolio.port}
    '';
  };

  mkBlogReverseProxyConfig = domain: {
    extraConfig = ''
      ${config.networking.certificates."${domain}".paths.caddy}

      ${commonHeaders}

      @blog path_regexp blog ^/blog(/(.*))?$
      redir @blog /{re.blog.2} 301

      @root path /
      rewrite @root /blog

      @notStatic not path /_next/* /api/* *.js *.css *.woff *.woff2 *.ttf *.otf *.png *.jpg *.jpeg *.gif *.svg *.ico *.pdf
      rewrite @notStatic /blog{path}

      reverse_proxy http://127.0.0.1:${toString config.services.portfolio.port}
    '';
  };
in
{
  services.portfolio = enabled {
    port = 30209;
  };

  networking.certificates = genAttrs domains mkCertConfig;

  services.caddy.virtualHosts =
    let
      mainConfigs = genAttrs domains (d: mkReverseProxyConfig d);
      wwwConfigs = genAttrs (map (d: "www.${d}") domains) (
        host:
        let
          domain = lib.removePrefix "www." host;
        in
        mkReverseProxyConfig domain
      );
      blogConfigs = genAttrs (map (d: "blog.${d}") domains) (
        host:
        let
          domain = lib.removePrefix "blog." host;
        in
        mkBlogReverseProxyConfig domain
      );
    in
    mainConfigs // wwwConfigs // blogConfigs;
}
