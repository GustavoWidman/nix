{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.pkg-config
    pkgs.krb5.dev
    pkgs.krb5.lib
    pkgs.openssl.dev
    pkgs.openssl.out
    pkgs.freetds
    pkgs.llvmPackages.libcxx
  ];
}
