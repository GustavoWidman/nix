{
  config,
  fenix,
  pkgs,
  ...
}:

let
  rustPkgs = fenix.packages.${config.metadata.architecture};
  complete = rustPkgs.complete;

  patchedRustcUnwrapped = complete.rustc-unwrapped.overrideAttrs (old: {
    installPhase =
      old.installPhase
      + pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
        # rust-objcopy/rust-lld look for libLLVM.dylib at @loader_path/../lib,
        # but the nightly rustc tarball currently only ships libLLVM.dylib in
        # $out/lib on macOS.
        if [ -f "$out/lib/libLLVM.dylib" ] && [ -d "$out/lib/rustlib" ]; then
          find "$out/lib/rustlib" -mindepth 2 -maxdepth 2 -type d -name bin | while read -r binDir; do
            targetDir="$(dirname "$binDir")"
            mkdir -p "$targetDir/lib"
            ln -sf "$out/lib/libLLVM.dylib" "$targetDir/lib/libLLVM.dylib"
          done
        fi
      '';
  });

  patchedRustc = rustPkgs.combine [
    patchedRustcUnwrapped
    complete.rust-std
  ];

  patchedClippy = rustPkgs.combine [
    complete.clippy-unwrapped
    patchedRustc
  ];

  rustToolchain = rustPkgs.combine [
    complete.cargo
    patchedClippy
    patchedRustc
    complete.rustfmt
    complete.rust-analyzer
    complete.rust-src
  ];
in

{
  environment.systemPackages = [
    rustToolchain
    pkgs.sccache
    pkgs.cargo-sweep
    pkgs.cargo-info
    pkgs.sqlx-cli
  ];

  home-manager.sharedModules = [
    {
      home.file.".cargo/config.toml" = {
        text = ''
          [net]
          git-fetch-with-cli = true

          [build]
          rustc-wrapper="sccache"
        '';
        force = true;
      };
    }
  ];
}
