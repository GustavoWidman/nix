{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    cargo-info
    # rust-src
    sqlx-cli
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
