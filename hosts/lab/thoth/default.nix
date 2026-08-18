{ ... }:
{
  # The service remains disabled until the AIO source tree is pinned as a flake
  # input or supplied through `services.thoth.source`. The Prime Agent 0.7.3
  # runtime itself is already pinned and built by packages/prime-agent.nix.
  services.thoth = {
    enable = false;
    # When enabled, point configFile at an agenix-decrypted thoth.toml.
  };
}
