{ config, lib, ... }:
let
  inherit (lib) head splitString;
in
{
  # Yeah, no DNSSEC or DoT or anything.
  # That's what you get for using Darwin I guess.
  # TODO find a way to get this to work with tailscale's DNS server.
  # networking.dns = config.dns.servers
  #   |> map (splitString "#")
  #   |> map head;

  networking.knownNetworkServices = [
    "Thunderbolt Bridge"
    "Wi-Fi"
  ];
}
