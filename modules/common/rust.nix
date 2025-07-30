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
    # rust-src
    sqlx-cli
  ];
}
