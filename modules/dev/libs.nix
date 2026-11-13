{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) concatMapStringsSep optionals;

  includePackages = [
    pkgs.krb5.dev
    pkgs.openssl.dev
    pkgs.freetds
  ]
  ++ optionals config.isDarwin [ pkgs.libiconv.dev ];

  libraryPackages = [
    pkgs.krb5.lib
    pkgs.openssl.out
    pkgs.freetds
    pkgs.llvmPackages.libcxx
  ]
  ++ optionals config.isDarwin [ pkgs.libiconv ];
in
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

  environment.variables = {
    NIX_LDFLAGS = concatMapStringsSep " " (pkg: "-L${pkg}/lib") libraryPackages;
    NIX_CFLAGS_COMPILE = concatMapStringsSep " " (pkg: "-isystem ${pkg}/include") includePackages;

    LDFLAGS = concatMapStringsSep " " (pkg: "-L${pkg}/lib") libraryPackages;
    CPPFLAGS = concatMapStringsSep " " (pkg: "-I${pkg}/include") includePackages;

    LIBRARY_PATH = concatMapStringsSep ":" (pkg: "${pkg}/lib") libraryPackages;
  };
}
