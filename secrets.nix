let
  inherit (import ./keys.nix)
    lab
    home-vm
    oracle-2
    laptop-mac

    linux
    darwin

    admins
    all
    ;
in
{
  # SSH Config
  "modules/common/ssh/id_ed25519.age".publicKeys = all;
  "modules/common/ssh/id_ed25519.pub.age".publicKeys = all;

  "modules/common/ssh/vms/config.age".publicKeys = all;
  "modules/common/ssh/vms/mac-arch.age".publicKeys = all;
  "modules/common/ssh/vms/vm.age".publicKeys = all;

  "modules/common/ssh/oracle/config.age".publicKeys = all;
  "modules/common/ssh/oracle/oracle-1.age".publicKeys = all;
  "modules/common/ssh/oracle/oracle-2.age".publicKeys = all;

  "modules/common/ssh/misc/config.age".publicKeys = all;
  "modules/common/ssh/misc/aur.age".publicKeys = all;
  "modules/common/ssh/misc/mwkey.age".publicKeys = all;
  "modules/common/ssh/misc/toninho.age".publicKeys = all;

  "modules/common/ssh/main/config.age".publicKeys = all;
  "modules/common/ssh/main/desktop.age".publicKeys = all;
  "modules/common/ssh/main/lab.age".publicKeys = all;

  "modules/common/ssh/github/config.age".publicKeys = all;
  "modules/common/ssh/github/inteli.age".publicKeys = all;
  "modules/common/ssh/github/personal.age".publicKeys = all;

  # General
  "modules/dev/aic/config.toml.age".publicKeys = all;

  # Linux Specific
  "modules/linux/tailscale/auth-key.age".publicKeys = linux ++ admins;
  "modules/server/acme/environment.env.age".publicKeys = linux ++ admins;

  # Home VM Specific
  "hosts/home-vm/password.age".publicKeys = [ home-vm ] ++ admins;

  # Lab Specific
  "hosts/lab/password.age".publicKeys = [ lab ] ++ admins;

  # Oracle-2 Specific
  "hosts/oracle-2/dailybot/config.toml.age".publicKeys = [ oracle-2 ] ++ admins;
  "hosts/oracle-2/dailybot/creds.json.age".publicKeys = [ oracle-2 ] ++ admins;
  "hosts/oracle-2/adguard/config.yaml.age".publicKeys = [ oracle-2 ] ++ admins;
  "hosts/oracle-2/password.age".publicKeys = [ oracle-2 ] ++ admins;
}
