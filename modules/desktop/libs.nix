{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    pkg-config
    krb5.dev
    krb5.lib
    openssl.dev
    openssl.out
    freetds
  ];
}
