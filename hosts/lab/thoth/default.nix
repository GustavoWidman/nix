{ ... }:
{
  # The service remains disabled until the AIO source tree is pinned as a flake
  # input or supplied through `services.thoth.source`. The Prime Agent 0.7.3
  # runtime itself is already pinned and built by packages/prime-agent.nix.
  services.thoth = {
    enable = false;

    # Hindsight remains an explicit external client. It is not a Thoth child.
    hindsight = {
      url = "http://127.0.0.1:8888";
      bankId = "prime-memory";
    };
  };
}
