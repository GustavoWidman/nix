{
  lib,
  pkgs,
  upstream,
}:
let
  upstreamPackages = upstream.packages.${pkgs.stdenv.hostPlatform.system};
  frontend = upstreamPackages.frontend.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./local-fonts.patch ];
    postPatch = (old.postPatch or "") + ''
      mkdir -p src/app/fonts
      cp ${pkgs.inter}/share/fonts/truetype/InterVariable.ttf src/app/fonts/
      cp ${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-*.ttf src/app/fonts/
      if grep -R 'next/font/google' src; then
        echo "Oxi must not download Google Fonts in the Nix sandbox" >&2
        exit 1
      fi
    '';
    installPhase = old.installPhase + ''
      if ! find "$out/_next/static/media" -type f -name '*.ttf' | grep -q .; then
        echo "Oxi static export is missing its self-hosted fonts" >&2
        exit 1
      fi
    '';
  });
in
# Mirror the pinned upstream wrapper with the patched frontend. Merely replacing
# a path in upstream's buildCommand retains its original Nix string context and
# would still require the broken Google-font frontend as a build dependency.
pkgs.runCommand "oxi-email-server"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    passthru = {
      oxiBasePath = "";
      offlineFrontend = frontend;
    };
  }
  ''
    mkdir -p $out/bin $out/share/oxi
    cp -r ${frontend} $out/share/oxi/static
    cp ${upstreamPackages.backend}/bin/oxi-email-server $out/bin/.oxi-email-server-wrapped
    makeWrapper $out/bin/.oxi-email-server-wrapped $out/bin/oxi-email-server \
      --set-default STATIC_DIR "$out/share/oxi/static" \
      --set-default ENVIRONMENT "production" \
      --set-default BASE_PATH ${lib.escapeShellArg ""} \
      --set SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  ''
