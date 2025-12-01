{
  environment.etc."nix/nix.custom.conf".text = ''
    extra-experimental-features = external-builders
    external-builders = [{"systems":["aarch64-linux","x86_64-linux"],"program":"/usr/local/bin/determinate-nixd","args":["builder"]}]
  '';
}
