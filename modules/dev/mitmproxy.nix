{ lib, ... }:

let
  # nixpkgs moved mitmproxy-rs to 0.12.16 but left the macOS wheel's hash at
  # 0.12.15's, so mitmproxy fails its hash check on every mac.
  # NixOS/nixpkgs#591156 carries the fix; until nixpkgs has it, 0.12.16's wheel
  # is fetched with the hash PyPI publishes. Once nixpkgs fetches it on its own,
  # evaluation warns that this file can go.
  version = "0.12.16";
  stale = "sha256-7VaT+JsMvR0qjFoxuu0r16dLCq1oZy4IREwYaMOPSfg=";
  pypi = "sha256-ruw6Tl0NG8XJiyltwszNaXAxiOWUYlDU9n8eaxSYI+A=";
in
{
  nixpkgs.overlays = [
    (_: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyFinal: pyPrev: {
          mitmproxy-macos =
            let
              package = pyPrev.mitmproxy-macos;
              broken = package.version == version && package.src.outputHash == stale;
              obsolete = !broken && lib.versionAtLeast package.version version;
            in
            lib.warnIf obsolete
              "modules/dev/mitmproxy.nix can go: nixpkgs no longer gives mitmproxy-macos ${version} the stale hash it replaces"
              (
                if broken then
                  package.overridePythonAttrs (_: {
                    src = pyFinal.fetchPypi {
                      pname = "mitmproxy_macos";
                      inherit version;
                      format = "wheel";
                      dist = "py3";
                      python = "py3";
                      hash = pypi;
                    };
                  })
                else
                  package
              );
        })
      ];
    })
  ];
}
