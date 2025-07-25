let
  inherit (import ./keys.nix)
    laptop-mac
    lab
    linux
    darwin
    admins
    all
    ;
in
{
  # SSH Config
  "modules/common/ssh/config.age".publicKeys = all;
  "modules/common/ssh/id_ed25519.age".publicKeys = all;
  "modules/common/ssh/id_ed25519.pub.age".publicKeys = all;

  "modules/common/ssh/cfg/vms/config.age".publicKeys = all;
  "modules/common/ssh/cfg/vms/mac-arch.age".publicKeys = all;
  "modules/common/ssh/cfg/vms/vm.age".publicKeys = all;

  "modules/common/ssh/cfg/oracle/config.age".publicKeys = all;
  "modules/common/ssh/cfg/oracle/oracle-1.age".publicKeys = all;
  "modules/common/ssh/cfg/oracle/oracle-2.age".publicKeys = all;

  "modules/common/ssh/cfg/misc/config.age".publicKeys = all;
  "modules/common/ssh/cfg/misc/aur.age".publicKeys = all;
  "modules/common/ssh/cfg/misc/mwkey.age".publicKeys = all;
  "modules/common/ssh/cfg/misc/toninho.age".publicKeys = all;

  "modules/common/ssh/cfg/main/config.age".publicKeys = all;
  "modules/common/ssh/cfg/main/desktop.age".publicKeys = all;
  "modules/common/ssh/cfg/main/lab.age".publicKeys = all;

  "modules/common/ssh/cfg/github/config.age".publicKeys = all;
  "modules/common/ssh/cfg/github/inteli.age".publicKeys = all;
  "modules/common/ssh/cfg/github/personal.age".publicKeys = all;

  # Passwords
  "hosts/lab/password.age".publicKeys = [ lab ] ++ admins;
  "hosts/laptop-mac/pubkey.age".publicKeys = all;

  # Tailscale
  "modules/linux/tailscale/auth-key.age".publicKeys = linux ++ admins;
}
