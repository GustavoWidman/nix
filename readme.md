# r3dlust's nix config collection

my entire digital life, codified and trapped in a repository.

this repository manages the configuration for my machines across nixos and
macos. it is declarative, which means new machines don't get hand-configured
into a weird bespoke snowflake. they get a host folder, a flake, secrets, and a
deploy command.

## infrastructure overview

this flake currently knows about 5 hosts:

- **`laptop-mac`** (darwin, aarch64): my daily driver macbook. runs aerospace,
  ghostty, homebrew bits, and the usual macos crimes.
- **`desktop-nixos`** (nixos, x86_64): my main linux desktop. runs hyprland,
  wayland, and all the gaming/heavy lifting stuff.
- **`lab`** (nixos, x86_64): a remote dev server that runs at home 24/7. i ssh
  into it from anywhere and use it for development work that shouldn't depend
  on whichever laptop is open.
- **`oracle-1`** (nixos, aarch64): oracle cloud server. formerly the awkward
  arch box waiting to be ported; now part of the flake like a civilized machine.
- **`oracle-2`** (nixos, aarch64): oracle cloud server that handles backend
  routing and serves most of my personal projects that need to be online.

## deployment

deployments are handled by `deploy.nu`, a nushell script i wrote because writing
bash in 2026 should be considered a war crime. it uses `nh` under the hood for
local builds and handles remote deployments over ssh.

```bash
# rebuild the current machine
./deploy.nu

# rebuild a named local host
./deploy.nu desktop-nixos

# rebuild a remote machine
./deploy.nu --remote lab

# first deploy to a remote host
./deploy.nu oracle-1 --remote oracle-1 --initial

# build every reachable host sequentially
./deploy.nu all
```

the script can also update flake inputs with `--update`, split remote work with
`--build-only` and `--apply-only`, skip staging with `--no-git`, and fetch a new
host's ssh host key during `--initial`.

fun fact: since my own shell loads a `.nu` file as a local toolchain, i actually
use the `deploy.nu` script simply as `deploy`:

```bash
# rebuild lab
deploy -r lab

# rebuild local
deploy

# rebuild everyone
deploy all
```

## file structure

the repository is structured around modularity and avoiding spaghetti code.

```text
.
├── flake.nix        # entry point. ties inputs, hosts, and lib together
├── hosts/           # machine-specific configurations
│   ├── desktop-nixos/
│   ├── lab/
│   ├── laptop-mac/
│   ├── oracle-1/
│   └── oracle-2/
├── modules/         # shared configuration snippets
│   ├── common/      # stuff every machine gets
│   ├── desktop/     # gui stuff
│   ├── dev/         # developer tools
│   ├── linux/       # linux-only modules
│   ├── macos/       # macos-only modules
│   └── server/      # server-only modules
├── lib/             # custom nix helper functions
│   ├── system.nix   # assembles nixos and darwin configurations
│   └── values.nix   # small shared values/helpers
├── keys.nix         # age public keys and recipient groups
├── secrets.nix      # agenix secret definitions
└── deploy.nu        # deployment orchestrator
```

## code helpers & `lib`

`flake.nix` reads every `hosts/<name>/flake.nix`, collects the host metadata,
and exposes the generated systems through `nixosConfigurations`,
`darwinConfigurations`, top-level host aliases, `machineMetadata`, and
`machineFlakes`.

the `lib/` directory is where the magic happens, it's heavily inspired off of
rgbcube/ncc's `lib` module. instead of copy-pasting massive configurations for
each host, `lib/system.nix` exports builder functions like `linuxDesktopSystem`,
`linuxServerSystem`, `linuxDevServerSystem`, and `darwinDesktopSystem`.

when a new host is defined in `hosts/my-host/flake.nix`, it calls one of these
builder functions. the function scoops up the shared modules, adds the relevant
linux/darwin and desktop/server/dev pieces, injects overlays, and spits out a
nixos or darwin configuration.

it makes spinning up a new machine almost as easy as creating a new folder,
writing 20 lines of nix, and letting the deploy script bully the target into
shape.

## secrets

secrets are handled by `agenix`. public keys and recipient groups live in
`keys.nix`, while encrypted secrets are declared in `secrets.nix` and stored as
age files.

host-specific secrets can live next to the host config, for example
`hosts/oracle-2/password.age`. after changing recipient groups, rekey the
affected secrets before deploying, unless you enjoy debugging boot failures over
ssh. allegedly.

## initializing a new host

1. create a new folder in `hosts/`: `mkdir hosts/my-new-host`
2. create a `flake.nix` inside it, declaring the `metadata` (`hostname`,
   `class`, `type`, `architecture`).
3. call the appropriate lib function, such as `linuxServerSystem`,
   `linuxDevServerSystem`, `linuxDesktopSystem`, or `darwinDesktopSystem`.
4. add host-specific modules in the same folder and import them from that host
   flake.
5. add the host key to `keys.nix`, update `secrets.nix` recipients, and rekey
   anything the new machine needs.
6. run the initial deployment: `./deploy.nu my-new-host --remote my-new-host --initial`
7. grab a coffee while nix does its thing

## custom flakes

this repository pulls in a bunch of project and tool flakes directly from
github, including `kemono-pinger`, `portfolio`, `claude-who`, `rocky-bot`,
`kache`, `cliproxyapi`, `zen-browser`, `copyparty`, and a custom autobuild of
`zed`.

nix builds what it needs, caches what it can, and still occasionally finds a way
to make me stare at a terminal for 40 minutes. tradition matters.

---

don't copy my code blindly. you will break your machine. read it, understand it,
and steal the parts that don't suck.
