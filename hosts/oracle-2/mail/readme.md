# webmail

`mail.r3dlust.com` serves [Oxi](https://github.com/c0h1b4/oxi) using its upstream
Nix flake and NixOS module. `flake.lock` pins the application revision. The
backend serves the static frontend; no PHP, Node.js runtime, or Docker container
is used for webmail.

`packages/oxi` applies a local build fix to the pinned upstream frontend: Inter
and JetBrains Mono are bundled from locked nixpkgs font packages using
`next/font/local`. Builds need no Google Fonts access, and the Nix sandbox stays
enabled. The backend source filter also restores upstream's pinned
`account-session-expired.json` authentication-test fixture, which its Cargo
source filter omits. Backend tests remain enabled. The upstream backend and
NixOS module remain in use; the small wrapper mirrors upstream packaging with
the patched frontend.

- Caddy terminates HTTPS and proxies HTTP/WebSockets to `127.0.0.1:37993`.
- IMAP uses `mail.r3dlust.com:993` with certificate-verified TLS.
- SMTP uses `mail.r3dlust.com:587` with required STARTTLS.
- Sign in with an existing full email address and its mailbox password. No new
  agenix secret or shared application password is required. Do not put mailbox
  passwords in Nix configuration.
- Oxi runs as its own unprivileged user with the upstream systemd sandbox.
  Persistent caches/indexes live in `/var/lib/oxi` (mode `0700`, umask `0077`).
  Back this directory up before application upgrades; it can contain private mail.
- Only loopback is trusted for forwarded client IPs, allowing Oxi's login rate
  limiter to distinguish users behind Caddy. No backend firewall port is opened.

The old Roundcube container remains disabled and its Docker volumes are left
untouched. Mail stays on the existing Dovecot/Postfix server; Roundcube contacts
and preferences are **not** automatically migrated to Oxi.

After deploying the Oracle-2 configuration, check `systemctl status oxi` and
`curl --fail http://127.0.0.1:37993/api/health`, then visit
`https://mail.r3dlust.com` to verify login, reading and sending mail. A Nix build
alone does not verify real mailbox credentials or delivery.

Configuration regression check (from the repository root, on an ARM builder):

```sh
nix eval --impure --json --expr \
  'import ./tests/oxi-webmail.nix { flake = builtins.getFlake (toString ./.); }'
```
