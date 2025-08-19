let
  inherit (import ./keys.nix)
    lab
    home-vm
    oracle-2
    oracle-xray
    laptop-mac

    linux
    darwin

    server
    dev

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
  "modules/common/ssh/oracle/oracle-xray.age".publicKeys = all;

  "modules/common/ssh/misc/config.age".publicKeys = all;
  "modules/common/ssh/misc/aur.age".publicKeys = all;
  "modules/common/ssh/misc/mwkey.age".publicKeys = all;
  "modules/common/ssh/misc/toninho.age".publicKeys = all;
  "modules/common/ssh/misc/build.age".publicKeys = all;

  "modules/common/ssh/main/config.age".publicKeys = all;
  "modules/common/ssh/main/desktop.age".publicKeys = all;
  "modules/common/ssh/main/lab.age".publicKeys = all;

  "modules/common/ssh/github/config.age".publicKeys = all;
  "modules/common/ssh/github/inteli.age".publicKeys = all;
  "modules/common/ssh/github/personal.age".publicKeys = all;

  # Server Specific
  "modules/server/acme/environment.env.age".publicKeys = server ++ admins;

  # Linux Specific
  "modules/linux/tailscale/auth-key.age".publicKeys = linux ++ admins;

  # Home VM Specific
  "hosts/home-vm/password.age".publicKeys = [ home-vm ] ++ admins;

  # Lab Specific
  "hosts/lab/password.age".publicKeys = [ lab ] ++ admins;

  # Oracle-2 Specific
  "hosts/oracle-2/dailybot/config.toml.age".publicKeys = [ oracle-2 ] ++ admins;
  "hosts/oracle-2/dailybot/creds.json.age".publicKeys = [ oracle-2 ] ++ admins;
  "hosts/oracle-2/adguard/config.yaml.age".publicKeys = [ oracle-2 ] ++ admins;
  "hosts/oracle-2/xray/config.json.age".publicKeys = [ oracle-2 ] ++ admins;
  "hosts/oracle-2/password.age".publicKeys = [ oracle-2 ] ++ admins;
  # Oracle-Xray Specific
  "hosts/oracle-xray/password.age".publicKeys = [ oracle-xray ] ++ admins;
}
