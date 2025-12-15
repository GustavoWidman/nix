{
  # environment.etc."nix/nix.custom.conf".text = ''
  #   !include /etc/nix/nix.darwin.conf
  # '';

  # environment.etc."nix/nix.darwin.conf".text = ''
  #   extra-experimental-features = external-builders
  # external-builders = [{"systems":["aarch64-linux","x86_64-linux"],"program":"/usr/local/bin/determinate-nixd","args":["builder"]}]
  # '';
  #
  nix-settings = {
    # extra-experimental-features = [ "external-builders" ];
    # external-builders = "[{\"systems\":[\"aarch64-linux\",\"x86_64-linux\"],\"program\":\"/usr/local/bin/determinate-nixd\",\"args\":[\"builder\"]}]";
  };
}
