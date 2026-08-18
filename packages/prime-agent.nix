{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_22,
  runCommand,
}:
let
  version = "0.7.3";
  tarball = fetchurl {
    url = "https://pub-728493de92a943e2a9b2d17b4719f318.r2.dev/releases/v${version}/prime-agent-${version}.tgz";
    hash = "sha256-KhiHODGLkf+R6ne4oLIVxBVDzwSD/LGKU0ddxOcDJ4Q=";
  };
  src = runCommand "prime-agent-${version}-source" { } ''
    mkdir -p "$out"
    tar -xzf ${tarball} --strip-components=1 -C "$out"
    cp ${./prime-agent-package-lock.json} "$out/package-lock.json"
  '';
in
buildNpmPackage {
  pname = "prime-agent";
  inherit version src;
  npmDepsHash = "sha256-O82F9Lx0eEmuIa2Cb476m1NdYCsJECcO4c7HxD30wvE=";
  nodejs = nodejs_22;
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp -a . "$out/"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/prime-agent" \
      --add-flags "$out/dist/bundle/cli.js"
    runHook postInstall
  '';
}
