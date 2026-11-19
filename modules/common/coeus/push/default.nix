{ config, lib, ... }:
let
  origin = "https://coeus.r3dlust.com";
  norn = config.services.norn;
  web = config.services.coeus.web;
  # coeus web reads the list as its own user on a mac, where one owner cannot
  # serve it and the main user's CLI both; on nixos systemd hands it over
  webCopy = config.isDarwin && web.enable;
in
{
  # the key that signs every push and the devices it goes to. the main user's
  # CLI reads both for the deploys it follows from a terminal; root's coeusd
  # and norn's credentials read them whoever owns them
  secrets = {
    coeus-push-vapid = {
      file = ./vapid.age;
      owner = config.mainUser;
      mode = "400";
    };
    coeus-push-subscriptions = {
      file = ./subscriptions.age;
      owner = config.mainUser;
      mode = "400";
    };
    coeus-push-subscriptions-web = lib.mkIf webCopy {
      file = ./subscriptions.age;
      owner = "_coeusweb";
      mode = "400";
    };
  };

  # deploy summaries from the CLI, catch-ups from coeusd
  services.coeus.push = {
    inherit origin;
    vapidKeyFile = config.secrets.coeus-push-vapid.path;
    subscriptionsFile = config.secrets.coeus-push-subscriptions.path;
  };

  # the dashboard's "this device" screen: the key a device subscribes with,
  # and the list it checks that device's subscription against
  services.coeus.web.push = lib.mkIf web.enable {
    publicKey = "BEo8q3NTLApTnGv2AJ8drkW3PlEqyhDxPJFe7uDv4S_mdlfyCUeCiPlPooZpjGP71JwVNl3R0WDfZg9eETjeaos";
    subscriptionsFile =
      config.secrets.${
        if webCopy then "coeus-push-subscriptions-web" else "coeus-push-subscriptions"
      }.path;
    edit = "agenix -e modules/common/coeus/push/subscriptions.age";
  };

  # a notice once this machine's norn runs have stayed troubled, and one when
  # they recover
  services.norn.push = lib.mkIf norn.enable {
    enable = true;
    vapidKeyFile = config.secrets.coeus-push-vapid.path;
    subscriptionsFile = config.secrets.coeus-push-subscriptions.path;
    subject = origin;
    navigate = "${origin}/machines/{host}";
  };
}
