{ config, lib, ... }:
lib.mkIf config.services.norn.enable {
  # zone read and dns edit on the three managed zones, nothing else
  secrets.norn-cloudflare-token.file = ./cloudflare-token.age;
  services.norn.tokenFile = config.secrets.norn-cloudflare-token.path;
}
