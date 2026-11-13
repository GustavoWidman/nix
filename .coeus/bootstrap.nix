# what `coeus bootstrap` asks of this repository: the questions about a new
# machine, the files and secrets that enroll it, and who opens each secret.
#
# coeus evaluates this file with
#
#   nix eval --json --file .coeus/bootstrap.nix --apply '<function>'
#
# so it uses builtins only: no nixpkgs, no flake input. secrets.nix derives
# agenix's rules from the same `recipients`, so coeus and agenix agree.
#
# a machine is its directory, hosts/<name>/: keys.nix finds its key in
# host.pub and its groups in its metadata. enrolling one only adds files.
let
  inherit (builtins)
    concatStringsSep
    elem
    elemAt
    filter
    foldl'
    head
    isString
    length
    map
    match
    split
    stringLength
    substring
    ;

  keys = import ../keys.nix;

  segments = path: filter isString (split "/" path);
  startsWith = prefix: text: substring 0 (stringLength prefix) text == prefix;
  endsWith =
    suffix: text:
    stringLength text >= stringLength suffix
    && substring (stringLength text - stringLength suffix) (stringLength suffix) text == suffix;
  unique = foldl' (seen: key: if elem key seen then seen else seen ++ [ key ]) [ ];

  # the values written into nix files, checked so they stay plain strings
  checked =
    what: pattern: value:
    if isString value && match pattern value != null then
      value
    else
      throw "coeus bootstrap: ${what} ${builtins.toJSON value} does not match ${pattern}";

  # ── who opens each secret ──────────────────────────────────────────────────

  hostKey =
    name:
    keys.${name}
      or (throw "coeus bootstrap: hosts/${name} has no host key; write hosts/${name}/flake.nix and hosts/${name}/host.pub first");

  # a secret's audience follows from where it lives:
  #   hosts/<name>/**     that machine and the admins
  #   modules/common/**   every machine
  #   modules/desktop/**  all desktops and the admins
  #   modules/dev/**      all desktops, dev-servers and the admins
  #   modules/linux/**    the nixos machines and the admins
  #   modules/macos/**    the darwin machines and the admins
  #   modules/server/**   all servers, dev-servers and the admins
  # null: not a secret this repository manages
  recipients =
    path:
    let
      parts = segments path;
    in
    if !(endsWith ".age" path) then
      null
    else if head parts == "hosts" && length parts > 2 then
      unique ([ (hostKey (elemAt parts 1)) ] ++ keys.admins)
    else if startsWith "modules/common/" path then
      keys.all
    else if startsWith "modules/desktop/" path then
      unique (keys.desktop ++ keys.admins)
    else if startsWith "modules/dev/" path then
      unique (keys.dev ++ keys.admins)
    else if startsWith "modules/linux/" path then
      unique (keys.linux ++ keys.admins)
    else if startsWith "modules/macos/" path then
      unique (keys.darwin ++ keys.admins)
    else if startsWith "modules/server/" path then
      unique (keys.server ++ keys.admins)
    else
      null;

  # ── the questions ──────────────────────────────────────────────────────────

  questions =
    { name, facts, ... }:
    [
      {
        id = "type";
        prompt = "what is ${name} for?";
        kind = "choice";
        choices = [
          {
            value = "server";
            label = "server";
            help = "always on, no screen";
          }
          {
            value = "dev-server";
            label = "dev server";
            help = "a server you also develop on, with the dev toolchain";
          }
          {
            value = "desktop";
            label = "desktop";
            help = "a machine a person sits at";
          }
        ];
        default = if facts.platform == "darwin" then "desktop" else "server";
      }
      {
        id = "admin";
        prompt = "make ${name} an admin, able to open every secret and bootstrap other machines?";
        kind = "confirm";
        default = "false";
      }
    ];

  # ── the files of a new machine ─────────────────────────────────────────────

  # the fleet's zone, for a machine that reports none
  defaultTimeZone = "America/Sao_Paulo";

  # the newest nix-darwin state version the fleet's macs run
  darwinStateVersion = 6;

  # `text` without its final newline, each line after `prefix`
  indent =
    prefix: text:
    let
      body = if endsWith "\n" text then substring 0 (stringLength text - 1) text else text;
    in
    concatStringsSep "\n" (
      map (line: if line == "" then "" else prefix + line) (filter isString (split "\n" body))
    );

  # hosts/<name>/flake.nix, in the shape every other host has
  hostFlake =
    {
      name,
      class,
      type,
      admin,
      system,
      body,
    }:
    let
      # desktops are not always on, so no machine builds on them
      buildArchitectures = if type == "desktop" then "[ ]" else "[\n      metadata.architecture\n    ]";
    in
    ''
      parent:
      let
        metadata = {
          hostname = "${name}";
          class = "${class}";
          type = "${type}";
          architecture = "${system}";
      ${if admin then "    admin = true;\n" else ""}    build-architectures = ${buildArchitectures};
        };
      in
      {
        inputs = parent;

        outputs = {
          inherit metadata;

          config =
            inputs@{
              ...
            }:
            inputs.lib.mkSystem inputs metadata (
              {
                config,
                lib,
                pkgs,
                ...
              }:
              let
                inherit (lib) collectNix remove;
              in
              {
                inherit metadata;

                imports = collectNix ./. |> remove ./flake.nix;

                networking.hostName = metadata.hostname;
                nixpkgs.hostPlatform = metadata.architecture;

      ${indent "          " body}
              }
            );
        };
      }
    '';

  # root and r3dlust log in with the password hash in password.age; r3dlust
  # authorizes the public half of modules/common/ssh/main/<name>
  nixosBody =
    { name, facts }:
    let
      timeZone = checked "time zone" "[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*" (
        if facts.timeZone or null == null then defaultTimeZone else facts.timeZone
      );
      stateVersion = checked "state version" "[0-9]+\\.[0-9]+" facts.stateVersion;
    in
    ''
      secrets.password.file = ./password.age;
      users.users.r3dlust.authorizedKey = config.secrets.ssh-main-${name}.path;

      time.timeZone = "${timeZone}";
      system.stateVersion = "${stateVersion}";
    '';

  # the mac keeps the account it was set up with as its main user, and joins
  # the tailnet on its own with the fleet's auth key (modules/macos/tailscale.nix)
  darwinBody =
    { name, user }:
    let
      home = "/Users/${user}";
    in
    ''
      users.users = {
        ${user} = {
          name = "${user}";
          home = "${home}";
          isMainUser = true;
          shell = pkgs.nushell;
          authorizedKey = config.secrets.ssh-main-${name}.path;
        };

        root = {
          name = "root";
          home = "/var/root";
          shell = pkgs.nushell;
        };
      };

      home-manager.users = {
        root.home = {
          stateVersion = "25.05";
          homeDirectory = "/var/root";
        };

        ${user}.home = {
          stateVersion = "25.05";
          homeDirectory = "${home}";
        };
      };

      tailscale.enable = true;

      system.stateVersion = ${toString darwinStateVersion};
    '';

  # the boot loader the machine was installed with, on the disk it boots from
  bootNix =
    facts:
    let
      device = checked "boot device" "/[A-Za-z0-9/._:-]+" facts.bootDevice;
      loader = facts.bootLoader or null;
      efi = facts.efi or false;
    in
    if loader == "systemd-boot" then
      ''
        {
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
        }
      ''
    else if loader == "grub" && efi then
      ''
        {
          boot.loader.grub = {
            enable = true;
            efiSupport = true;
            device = "nodev";
          };
          boot.loader.efi.canTouchEfiVariables = true;
        }
      ''
    else if loader == "grub" then
      ''
        {
          boot.loader.grub = {
            enable = true;
            device = "${device}";
          };
        }
      ''
    else if loader == "limine" && efi then
      ''
        {
          boot.loader.limine.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
        }
      ''
    else if loader == "limine" then
      ''
        {
          boot.loader.limine = {
            enable = true;
            efiSupport = false;
            biosDevice = "${device}";
          };
        }
      ''
    else
      throw "coeus bootstrap: no boot loader this repository knows (${builtins.toJSON loader}); write the machine's boot.nix by hand";

  enroll =
    {
      name,
      hostKey,
      facts,
      answers,
      ...
    }:
    let
      host = checked "machine name" "[a-z0-9][a-z0-9-]*" name;
      darwin = facts.platform == "darwin";
      class = if darwin then "darwin" else "nixos";
      type = checked "machine type" "server|dev-server|desktop" answers.type;
      admin = answers.admin or "false" == "true";
      system = checked "system" "(x86_64|aarch64)-(linux|darwin)" facts.system;
      user = if darwin then checked "main user" "[A-Za-z_][A-Za-z0-9_.-]*" facts.mainUser else "r3dlust";
      dir = "hosts/${host}";
      typeLabel = if type == "dev-server" then "dev server" else type;
    in
    {
      files = {
        "${dir}/flake.nix" = hostFlake {
          inherit
            class
            type
            admin
            system
            ;
          name = host;
          body =
            if darwin then
              darwinBody {
                name = host;
                inherit user;
              }
            else
              nixosBody {
                name = host;
                inherit facts;
              };
        };
        "${dir}/host.pub" = checked "host key" "ssh-ed25519 [A-Za-z0-9+/=]+" hostKey + "\n";
      }
      // (
        if darwin then
          { }
        else
          {
            "${dir}/hardware.nix" =
              if isString (facts.hardwareConfig or null) then
                facts.hardwareConfig
              else
                throw "coeus bootstrap: ${host} reported no hardware configuration";
            "${dir}/boot.nix" = bootNix facts;
          }
      );

      secrets = {
        # every machine gets it as ~/.ssh/main/${host} (modules/common/ssh.nix)
        # and ${host} authorizes its public half (modules/common/auth-privkey.nix)
        "modules/common/ssh/main/${host}.age" = {
          kind = "ssh-ed25519";
          comment = "${user}@${host}";
        };
      }
      // (
        if darwin then
          { }
        else
          {
            # hashedPasswordFile of root, r3dlust and build (modules/linux/users.nix)
            "${dir}/password.age" = {
              kind = "password";
              prompt = "password for root and r3dlust on ${host}";
            };
          }
      );

      # the loader is the one the machine boots with, so installing it again
      # touches the same disk; the stock generation never installed this one
      firstSwitch.installBootloader = !darwin;

      messages = {
        enroll = "feat(${host}): add ${class} ${typeLabel} host";
        rekey = "chore(secrets): rekey for ${host}";
        title = "feat(${host}): add ${class} ${typeLabel} host";
        body = ''
          Adds `${host}`, a ${class} ${typeLabel} on ${system}${
            if admin then ", as an admin" else ""
          }, to the fleet.

          Merging it deploys the fleet, which tells every other machine about
          `${host}`, and gives each one its login key under `~/.ssh/main/${host}`.
        '';
      };

      notes = [
        "add a Host entry for ${host} to modules/common/ssh/main/config.age (agenix -e), so `ssh ${host}` logs in with its key"
      ]
      ++ (
        if darwin then
          [
            "on ${host}, run `coeus doctor --fix` and drag coeus-launcher into Full Disk Access, so nix-darwin can create and delete users"
          ]
        else
          [ ]
      );
    };
in
{
  version = 1;
  identity = "/etc/ssh/ssh_host_ed25519_key";

  inherit questions enroll recipients;
}
