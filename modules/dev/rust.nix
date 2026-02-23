{
  fenix,
  pkgs,
  ...
}:

{
  environment.systemPackages = [
    (pkgs.fenix.complete.withComponents [
      "cargo"
      "clippy"
      "rustc"
      "rustfmt"
      "rust-analyzer"
    ])
    pkgs.cargo-info
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
