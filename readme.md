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

# build every reachable host sequentially
./deploy.nu all
```

the script can also update flake inputs with `--update`, split remote work with
`--build-only` and `--apply-only`, and skip staging with `--no-git`. it only
rebuilds machines already in the flake; new ones come in through
`coeus bootstrap` (see [initializing a new host](#initializing-a-new-host)).

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
commit. machines that were asleep or offline look `deployed` up as soon as
they come back, and every 15 minutes after, and catch up on their own.

one-time step on each mac: nix-darwin needs full disk access to create or
delete users, and only a person can grant it. coeus runs activations under its
own `coeus-launcher`, installed once and never replaced, so the grant outlives
every update. run `coeus doctor --fix` on the mac and drag `coeus-launcher` into
the list it opens. routine deployments work without it.

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
├── .coeus/
│   └── bootstrap.nix # what `coeus bootstrap` writes for a new machine
├── keys.nix         # host keys and recipient groups, read from hosts/
├── secrets.nix      # agenix rules, derived from where each secret lives
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
shape. in practice `coeus bootstrap` writes those 20 lines for me.

## secrets

secrets are handled by `agenix`, and nobody writes keys or rules by hand:
each machine's ssh host key sits in `hosts/<name>/host.pub`, and `keys.nix`
builds the recipient groups (`admins`, `linux`, `darwin`, `server`, `dev`,
`all`) from host metadata. a machine with `admin = true;` opens every secret.

who opens a secret depends on where it lives, and `recipients` in
`.coeus/bootstrap.nix` spells it out: `hosts/<name>/` is that machine plus the
admins, `modules/common/` is everyone, `modules/linux/` and `modules/server/`
are those machines plus the admins. `secrets.nix` is just that function applied
to every `.age` file on disk, so `agenix -e` works as usual. a brand new secret
needs its file before its rule:

```bash
touch hosts/lab/new.age && agenix -e hosts/lab/new.age < plaintext
```

after a machine joins or leaves a group, rekey before deploying, unless you
enjoy debugging boot failures over ssh. allegedly. `coeus bootstrap` does that
part on its own.

## initializing a new host

new machines join with `coeus bootstrap`, run from an admin machine against
anything that already runs nixos (a stock install is fine) or macos (it gets
determinate nix if it lacks it):

```bash
coeus bootstrap my-new-host --to nixos@192.168.1.50
```

it asks what the machine is for (server, dev server or desktop) and whether
it should be an admin, then does the whole dance:

1. writes `hosts/my-new-host/`: a `flake.nix` with the right builder, the
   machine's `host.pub`, and on nixos its `hardware.nix` and a `boot.nix`
   keeping the boot loader it was installed with.
2. creates its secrets: the main user's login key under
   `modules/common/ssh/main/`, and on nixos the root/r3dlust password, which
   it asks for.
3. rekeys every secret the new machine (or new admin) should open.
4. pushes a `coeus/bootstrap/my-new-host` branch and opens a draft pull
   request.
5. does the first switch on the machine itself, follows it live, and checks
   `coeusd` answers over the tailnet afterwards.
6. marks the pull request ready. merge it, and the next deploy tells every
   other machine about the new one.

what goes into `hosts/<name>/` and which secrets it gets is decided by
`.coeus/bootstrap.nix`, not by coeus, so changing what a new host looks like
means editing that file. stopping it halfway is fine: running the same command
again picks up where it left off. on a mac, finish with `coeus doctor --fix`
(see [coeus](#coeus)).

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
