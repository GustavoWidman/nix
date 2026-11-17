{ config, lib, ... }:
lib.mkIf config.services.norn.enable {
  # where agenix puts the norn-cloudflare-token secret. agenix can only
  # declare it once its file, modules/server/norn/cloudflare-token.age, exists
  services.norn.tokenFile = "${config.age.secretsDir}/norn-cloudflare-token";
}
