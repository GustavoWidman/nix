{
  fenix,
  pkgs,
  ...
}:

{
  nixpkgs.overlays = [ fenix.overlays.default ];
  environment.systemPackages = [
    (pkgs.fenix.complete.withComponents [
      "cargo"
      "clippy"
      "rustc"
      "rustfmt"
    ])
    pkgs.cargo-info
    pkgs.rust-analyzer
    pkgs.sqlx-cli
  ];

  home-manager.sharedModules = [
    {
      home.file.".cargo/config.toml" = {
        text = ''
          [net]
          git-fetch-with-cli = true
        '';
        force = true;
      };
    }
  ];
}
