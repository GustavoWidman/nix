# modules/linux/tailscale-certificate.nix in a vm, with the real tailscaled
# and a `tailscale cert` that issues self-signed certificates instead of
# asking let's encrypt: /run/fake-cert/serial numbers the one it hands back,
# so the test renews by changing it, and /run/fake-cert/fail makes it fail.
#
# reader-reload and reader-restart read the certificate as the user `reader`,
# which is not in `users`, so only reloadServices gives them access. each logs
# `start <fingerprint>`, or `start denied` when it cannot read the files;
# reader-reload logs `reload <fingerprint>` on SIGHUP, and reader-restart has
# no reload. reader-late reads it too, outside reloadServices until a
# specialisation adds it. the specialisations change `users` and
# reloadServices after the certificate exists.
{ lib, ... }:
{
  name = "tailscale-certificate";

  nodes.machine =
    { pkgs, ... }:
    let
      fakeTailscale = pkgs.symlinkJoin {
        name = "tailscale-fake-cert";
        # the first path's bin/tailscale wins over the real one
        paths = [
          (pkgs.writeShellScriptBin "tailscale" ''
            if [ "''${1:-}" != cert ]; then
              exec ${lib.getExe pkgs.tailscale} "$@"
            fi
            shift
            while [ $# -gt 0 ]; do
              case $1 in
                --cert-file) cert=$2; shift 2 ;;
                --key-file) key=$2; shift 2 ;;
                *) domain=$1; shift ;;
              esac
            done
            echo "$domain" >> /run/fake-cert/calls
            if [ -e /run/fake-cert/fail ]; then
              echo "cannot reach let's encrypt" >&2
              exit 1
            fi
            issued=/var/lib/fake-cert/$(cat /run/fake-cert/serial)
            if [ ! -e "$issued/cert.pem" ]; then
              mkdir -p "$issued"
              ${lib.getExe pkgs.openssl} req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
                -nodes -days 90 -subj "/CN=$domain" -keyout "$issued/key.pem" -out "$issued/cert.pem" 2>/dev/null
            fi
            cp "$issued/cert.pem" "$cert"
            cp "$issued/key.pem" "$key"
          '')
          pkgs.tailscale
        ];
        meta.mainProgram = "tailscale";
      };

      reader = pkgs.writeShellScript "reader" ''
        read_certificate() {
          if sum=$(sha256sum /var/lib/tailscale-cert/cert.pem 2>/dev/null) \
            && cat /var/lib/tailscale-cert/key.pem >/dev/null 2>&1; then
            echo "$1 ''${sum:0:16}"
          else
            echo "$1 denied"
          fi
        }
        read_certificate start
        trap 'read_certificate reload' HUP
        while true; do
          sleep 1 &
          wait $!
        done
      '';

      readerService = extra: {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = reader;
          User = "reader";
          Group = "reader";
        }
        // extra;
      };
    in
    {
      imports = [ ../modules/linux/tailscale-certificate.nix ];

      services.tailscale = {
        enable = true;
        package = fakeTailscale;
      };

      systemd.tmpfiles.rules = [
        "d /run/fake-cert 0755 root root -"
        "f /run/fake-cert/serial 0644 root root - 1"
      ];

      users.mutableUsers = false;
      users.allowNoPasswordLogin = true;
      users.users = {
        alice.isNormalUser = true;
        bob.isNormalUser = true;
        carol.isNormalUser = true;
        reader = {
          isSystemUser = true;
          group = "reader";
        };
      };
      users.groups.reader = { };

      tailscale.certificate = {
        enable = true;
        users = [
          "alice"
          "bob"
        ];
        reloadServices = [
          "reader-reload"
          "reader-restart.service"
        ];
      };

      systemd.services = {
        reader-reload = readerService { ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID"; };
        reader-restart = readerService { };
        reader-late = readerService { };
      };

      specialisation = {
        user-added.configuration.tailscale.certificate.users = [ "carol" ];
        user-removed.configuration.tailscale.certificate.users = lib.mkForce [ "alice" ];
        service-added.configuration.tailscale.certificate.reloadServices = [ "reader-late" ];
        service-removed.configuration.tailscale.certificate.reloadServices = lib.mkForce [
          "reader-reload"
        ];
      };
    };

  testScript = ''
    dir = "/var/lib/tailscale-cert"


    def fingerprint():
        return machine.succeed(f"sha256sum {dir}/cert.pem | cut -c1-16").strip()


    def logged(unit):
        """Every line the reader logged, oldest first."""
        out = machine.succeed(f"journalctl -u {unit} -o cat --no-pager | grep -E '^(start|reload) ' || true")
        return out.split("\n")[:-1]


    def wait_logged(unit, line):
        machine.wait_until_succeeds(f"journalctl -u {unit} -o cat --no-pager | grep -qx '{line}'", timeout=30)


    def reads(user):
        status, _ = machine.execute(f"runuser -u {user} -- cat {dir}/cert.pem {dir}/key.pem > /dev/null")
        return status == 0


    def main_pid(unit):
        return machine.succeed(f"systemctl show -p MainPID --value {unit}").strip()


    def calls():
        return int(machine.succeed("wc -l < /run/fake-cert/calls").strip())


    def request():
        """Runs tailscale-cert; systemd's start limit would refuse the test's quick restarts."""
        machine.succeed("systemctl reset-failed tailscale-cert.service")
        return machine.execute("systemctl start tailscale-cert.service")[0] == 0


    def renew(serial):
        machine.succeed(f"echo {serial} > /run/fake-cert/serial")
        assert request()


    machine.wait_for_unit("multi-user.target")
    base = machine.succeed("readlink -f /run/current-system").strip()


    def switch(specialisation=None):
        target = f"{base}/specialisation/{specialisation}" if specialisation else base
        machine.succeed(f"{target}/bin/switch-to-configuration test")


    with subtest("the certificate is written before the services that read it start"):
        machine.wait_for_unit("reader-reload.service")
        machine.wait_for_unit("reader-restart.service")
        first = fingerprint()
        assert logged("reader-reload") == [f"start {first}"], logged("reader-reload")
        assert logged("reader-restart") == [f"start {first}"], logged("reader-restart")
        machine.succeed("grep -qx machine.tail4a3ea.ts.net /run/fake-cert/calls")
        machine.succeed(f"stat -c '%a %U %G' {dir} | grep -qx '750 root tailscale-cert'")
        for name in ["cert.pem", "key.pem"]:
            machine.succeed(f"stat -c '%a %U %G' {dir}/{name} | grep -qx '640 root tailscale-cert'")
        machine.succeed("systemctl list-timers tailscale-cert.timer | grep -q tailscale-cert.timer")

    with subtest("the users listed from the start read it, and no one else"):
        assert reads("alice") and reads("bob")
        assert not reads("carol")
        assert logged("reader-late") == ["start denied"], logged("reader-late")

    with subtest("an unchanged certificate replaces nothing and reloads nothing"):
        files = machine.succeed(f"stat -c '%i %Y' {dir}/cert.pem {dir}/key.pem")
        pids = (main_pid("reader-reload"), main_pid("reader-restart"))
        before = calls()
        assert request()
        assert calls() == before + 1
        assert machine.succeed(f"stat -c '%i %Y' {dir}/cert.pem {dir}/key.pem") == files
        assert (main_pid("reader-reload"), main_pid("reader-restart")) == pids
        assert logged("reader-reload") == [f"start {first}"], logged("reader-reload")

    with subtest("a renewal reloads a service that can reload and restarts one that cannot"):
        reload_pid, restart_pid = main_pid("reader-reload"), main_pid("reader-restart")
        renew(2)
        second = fingerprint()
        assert second != first
        wait_logged("reader-reload", f"reload {second}")
        wait_logged("reader-restart", f"start {second}")
        assert main_pid("reader-reload") == reload_pid
        assert main_pid("reader-restart") != restart_pid
        assert reads("alice") and reads("bob") and not reads("carol")
        machine.succeed(f"stat -c '%a %G' {dir}/cert.pem {dir}/key.pem | sort -u | grep -qx '640 tailscale-cert'")
        machine.fail(f"ls -A {dir} | grep -q '^\\.'")

    with subtest("a renewal leaves a stopped service stopped"):
        machine.succeed("systemctl stop reader-restart.service")
        renew(3)
        third = fingerprint()
        wait_logged("reader-reload", f"reload {third}")
        machine.fail("systemctl is-active --quiet reader-restart.service")
        machine.succeed("systemctl start reader-restart.service")
        wait_logged("reader-restart", f"start {third}")

    with subtest("a failed request keeps the certificate and the services"):
        machine.succeed("touch /run/fake-cert/fail")
        machine.succeed("echo 4 > /run/fake-cert/serial")
        before = calls()
        assert not request()
        assert calls() == before + 1
        machine.succeed("rm /run/fake-cert/fail && echo 3 > /run/fake-cert/serial")
        assert fingerprint() == third
        assert logged("reader-reload")[-1] == f"reload {third}", logged("reader-reload")
        machine.succeed("systemctl is-active --quiet reader-reload.service reader-restart.service")

    with subtest("a user added after the certificate exists reads it"):
        switch("user-added")
        assert reads("carol") and reads("alice") and reads("bob")
        assert fingerprint() == third

    with subtest("a user removed after the certificate exists no longer reads it"):
        switch("user-removed")
        assert reads("alice")
        assert not reads("bob") and not reads("carol")

    with subtest("a service added to reloadServices restarts with access"):
        switch()
        assert logged("reader-late")[-1] == "start denied", logged("reader-late")
        switch("service-added")
        wait_logged("reader-late", f"start {third}")
        renew(5)
        fifth = fingerprint()
        wait_logged("reader-late", f"start {fifth}")
        wait_logged("reader-reload", f"reload {fifth}")

    with subtest("a service removed from reloadServices restarts without access"):
        reload_pid = main_pid("reader-reload")
        switch("service-removed")
        wait_logged("reader-restart", "start denied")
        assert main_pid("reader-reload") == reload_pid
        assert logged("reader-reload")[-1] == f"reload {fifth}", logged("reader-reload")

    with subtest("the base configuration again"):
        switch()
        wait_logged("reader-restart", f"start {fifth}")
        assert reads("alice") and reads("bob") and not reads("carol")
  '';
}
