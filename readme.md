# r3dlust's nix config collection

my entire digital life, codified and trapped in a repository.

this repository manages the configuration for my machines across nixos and
macos. it is declarative, which means new machines don't get hand-configured
into a weird bespoke snowflake. they get a host folder, a flake, secrets, and a
deploy command.

## infrastructure overview

this flake currently knows about 6 hosts:

- **`laptop-mac`** (darwin, aarch64): my daily driver macbook. runs aerospace,
  ghostty, homebrew bits, and the usual macos crimes.
- **`altar`** (darwin, aarch64): a headless mac mini dev server that exists to
  run ai agents. gets the dev toolchain, but no window manager, no login apps,
  never sleeps, and comes back on its own after a power cut.
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

## coeus

every machine also runs `coeusd`, the daemon half of
[coeus](https://github.com/GustavoWidman/coeus), my own deployment tool. it
listens on the tailnet (port 45729, `tailscale0` only on nixos), builds and
activates its own configuration from this repo when told to, and rolls itself
back if the new generation cuts it off the network. the `coeus` cli comes along
with it, already pointed at the whole fleet, which is read straight from the
`hosts/` folders. adding a host folder is all it takes to join.

```bash
# switch the whole fleet to main, lab first as the canary
coeus deploy @all --ref main --canary @canary

# only the nixos servers, and only on the next boot
coeus deploy @server --boot

# watch every machine, including rollouts nobody started from this terminal
coeus watch
```

nobody has to start rollouts by hand, though. every push to `main` makes
`.github/workflows/deploy.yml` join the tailnet as `tag:ci` and run
`coeus deploy` on the pushed commit: lab goes first, everyone else follows if
it survives, and any reachable machine failing fails the run. when the whole
fleet switches cleanly, the workflow moves the `deployed` branch to that
commit. machines that were asleep or offline check `deployed` every 15 minutes
and catch up on their own.

one-time step on each mac: nix-darwin's activation needs full disk access, and
coeus runs it under `/usr/bin/time` so that only that one binary needs it.
grant it in system settings > privacy & security > full disk access (hit `+`,
then `cmd+shift+g` and type `/usr/bin/time`). yes, really, `time`.

## file structure

the repository is structured around modularity and avoiding spaghetti code.

```text
.
├── flake.nix        # entry point. ties inputs, hosts, and lib together
├── hosts/           # machine-specific configurations
│   ├── altar/
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
`linuxServerSystem`, `linuxDevServerSystem`, `darwinDesktopSystem`,
`darwinServerSystem`, and `darwinDevServerSystem`.

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
   `linuxDevServerSystem`, `linuxDesktopSystem`, `darwinDesktopSystem`,
   `darwinServerSystem`, or `darwinDevServerSystem`.
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
