{ ... }:
{
  # The package and Prime Agent runtime come from the pinned Thoth flake input.
  # Keep the service disabled until the age-encrypted config is provisioned.
  services.thoth = {
    enable = false;
    # When enabled, point configFile at an agenix-decrypted thoth.toml.
  };
}
