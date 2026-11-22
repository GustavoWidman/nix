# r3dlust's nix config collection

my entire digital life, codified and trapped in a repository.

this repository manages the configuration for my machines across nixos and
macos. it is declarative, which means new machines don't get hand-configured
into a weird bespoke snowflake. they get a host folder, a flake, secrets, and a
deploy command.

## infrastructure overview

this flake currently knows about 6 hosts:

- **`laptop-mac`** (darwin, aarch64): my daily driver macbook. runs rift,
  ghostty, homebrew bits, and the usual macos crimes.
- **`altar`** (darwin, aarch64): a headless mac mini dev server that exists to
  run ai agents. gets the dev toolchain, but no window manager, no login apps,
  never sleeps, and comes back on its own after a power cut.
- **`desktop-nixos`** (nixos, x86_64): my main linux desktop, the nvidia box
  for the heavy lifting. its desktop session isn't managed here (yet).
- **`lab`** (nixos, x86_64): a remote dev server that runs at home 24/7. i ssh
  into it from anywhere and use it for development work that shouldn't depend
  on whichever laptop is open.
- **`oracle-1`** (nixos, aarch64): oracle cloud server. formerly the awkward
  arch box waiting to be ported; now part of the flake like a civilized machine.
- **`oracle-2`** (nixos, aarch64): oracle cloud server that handles backend
  routing and serves most of my personal projects that need to be online.

## deployment

every deployment goes through [coeus](#coeus): pushing to `main` rolls the
whole fleet, and `coeus deploy` does the same by hand for any set of machines.
for the machine you're sitting at, `nh` works too:

```bash
# rebuild the current nixos machine
nh os switch .

# rebuild the current mac
nh darwin switch .
```

every machine also lists the others as remote builders (`ssh-ng://build@<host>`
for the platforms in their `build-architectures`) and knows their ssh host keys
from `hosts/<name>/host.pub`. the nixos machines take those builds; the macs
have no `build` user yet, so nix skips them.

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
commit and runs `coeus catch-up`, so every machine that answers sees it moved
at once. machines that were asleep or offline look `deployed` up as soon as
they come back, and every 15 minutes after, and catch up on their own.

every machine reaches the tailnet without a click, as `tag:fleet`. the key in
`modules/common/tailscale/auth-key.age`, which every machine can open, is the
secret of a tailscale oauth client allowed to write auth keys for that tag: it
never expires, and a machine it signs in joins preauthorized, owned by the tag
rather than a person, with key expiry off. `tailscale.enable` (with
`tailscale.exit-node`, `tailscale.advertise-routes`, `tailscale.accept-routes`
and `tailscale.tags`)
drives both platforms, and it is on by default. nixos signs in through
`services.tailscale.authKeyFile`. on a mac, nix-darwin runs `tailscaled`, and a
`tailscale-autoconnect` launchd daemon runs `tailscale up` with the key
whenever `tailscaled` says it needs a login, retrying a few times before giving
up (see `/var/log/tailscale-autoconnect.log`). a mac already signed in is left
alone. the Tailscale app runs a tailscale of its own, so a mac running
`tailscaled` must not have the app installed too.

the fleet also pushes notifications to my phone and desktop, through the
dashboard at `coeus.r3dlust.com`: one summary per deploy, from the terminal or
from CI, a note whenever a machine catches up or gives up catching up, and
norn's word when a server's dns runs stay troubled for half an hour and when
they recover. the key that signs them and the list of devices are
`modules/common/coeus/push/vapid.age` and `subscriptions.age`; every machine
opens both, and CI opens them in memory with `COEUS_PUSH_IDENTITY`, the private
half of `.github/ci.pub`. a device subscribes on the dashboard's "this device"
screen, which shows the entry to add:

```bash
agenix -e modules/common/coeus/push/subscriptions.age   # paste the entry into the array
```

commit it and deploy, and `coeus push test` says hello to every device on the
list.

one-time step on each mac: nix-darwin needs full disk access to create or
delete users, and only a person can grant it. coeus runs activations under its
own `coeus-launcher`, installed once and never replaced, so the grant outlives
every update. run `coeus doctor --fix` on the mac and drag `coeus-launcher` into
the list it opens. routine deployments work without it.

## flake updates

input updates arrive as a pull request. every night at 00:17 (brt),
`.github/workflows/flake-update.yml` updates the flake's inputs on `main` and
keeps exactly one pull request, on the `flake-update` branch, holding
whatever is waiting. `.github/flake-update/inputs.toml` splits the inputs it
tracks into two lists:

- **triggers** open the pull request when they move.
- **passengers** ride along: they're updated when a trigger moved, or on any
  run while the pull request is open, but never open one on their own,
  because nobody needs a pull request for every homebrew-core commit.

every root input is in one of the two, so nothing is bumped by hand anymore.

an input pinned to a release tag, like taproot, would never move on its own,
since a tag never moves. a third list, **releases**, names those, and for
each one the bot rewrites the tag in flake.nix's url before it relocks it,
so its commit carries flake.nix along with flake.lock. an entry is either a
bare name, which follows the release github marks latest, or a table with a
regex, which follows the highest tag that fully matches it:

```toml
releases = [{ input = "taproot", tag = 'taproot-v\d+\.\d+\.\d+' }]
```

the regex has to match the whole tag, so taproot's release candidates stay
out, and "highest" is version order, numbers compared as numbers, so
`0.10.0` beats `0.9.0` and a backport tagged after a newer release doesn't
win. the bot only touches the url when it appears in flake.nix exactly once.

an input that fails to update keeps main's pin and is listed as stuck, with
its error, instead of stopping the rest.

every push of the branch gets checked twice. the runner evaluates all six
hosts and names any nixpkgs package that refuses to evaluate (broken,
insecure, unsupported, removed), and coeus builds the commit on every machine
that answers, without activating anything, naming the derivation that broke a
machine's build, under the pile of dependents nix fails along with it. both
show up as commit statuses and in the pull request's body, which is rebuilt
from scratch on every push, and a comment says what moved since the last one.
merging it is a push to `main`, so the usual deploy takes it from there.

- a push to `main` that touches `flake.lock` or `flake.nix`, like a manual
  bump, starts it too (`flake-update-rebase.yml`), so the pull request gets
  rebased and checked within minutes, dependabot style. pushes that touch
  anything else can't conflict with it and leave it alone.
- `gh workflow run flake-update` starts it by hand; add `-f open=true` to
  open the pull request even when only passengers moved.
- closing the pull request parks it: nothing reopens until a trigger moves
  past what the closed one had.
- commits you push to the branch are kept, and checked as soon as you push
  them. each refresh rebuilds the branch as main, the bot's commit, then
  yours, cherry-picked in order. if one no longer applies, the bot says so
  on the pull request once and leaves the branch alone.
- `FLAKE_INPUTS_TOKEN`, a fine-grained token that can read rocky-bot, is how
  the runner fetches the private input oracle-1 imports.

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
└── tests/           # vm tests, as checks.<system>
```

## code helpers & `lib`

`flake.nix` builds every machine under `hosts/` and exposes the systems through
`nixosConfigurations`, `darwinConfigurations`, top-level host aliases, and
`machineMetadata`.

the `lib/` directory is where the magic happens, it's heavily inspired off of
rgbcube/ncc's `lib` module. instead of copy-pasting massive configurations for
each host, `lib/system.nix` exports one builder, `mkSystem`.

a host is a folder: `hosts/my-host/flake.nix` holds its `metadata` (hostname,
class, type, architecture) and its top-level `module`, and every other file in
the folder is imported. `mkSystem` reads the class and type from the metadata,
scoops up the shared modules, adds the relevant linux/darwin and
desktop/server/dev pieces, injects overlays, and spits out a nixos or darwin
configuration.

it makes spinning up a new machine almost as easy as creating a new folder,
writing 20 lines of nix, and letting coeus bully the target into shape. in practice `coeus bootstrap` writes those 20 lines for me.

## secrets

secrets are handled by `agenix`, and nobody writes keys or rules by hand: each
machine's ssh host key sits in `hosts/<name>/host.pub`, and `keys.nix` builds
the recipient groups (`admins`, `linux`, `darwin`, `desktop`, `dev`, `server`,
`all`) from host metadata. a machine with `admin = true;` opens every secret.

who opens a secret depends on where it lives, and `recipients` in
`.coeus/bootstrap.nix` spells it out: `hosts/<name>/` is that machine plus the
admins, `modules/common/` is everyone, and every other module directory is the
machines that import it plus the admins: `modules/linux/` and `modules/macos/`
go by platform, `modules/desktop/` to desktops, `modules/dev/` to desktops and
dev servers, `modules/server/` to servers and dev servers. one directory is
an exception: `modules/common/coeus/push/` also goes to `keys.ci`, the deploy
workflow's own key in `.github/ci.pub`, which is in no group and opens nothing
else. `secrets.nix` is
just that function applied to every `.age` file on disk, so `agenix -e` works
as usual. a brand new secret needs its file before its rule:

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

1. writes `hosts/my-new-host/`: a `flake.nix` with its metadata and module, the
   machine's `host.pub`, and on nixos its `hardware.nix` and a `boot.nix`
   keeping the boot loader it was installed with.
2. creates its secrets: the main user's login key under
   `modules/common/ssh/main/`, and on nixos the root/r3dlust password, which
   it asks for.
3. rekeys every secret the new machine (or new admin) should open.
4. pushes a `coeus/bootstrap/my-new-host` branch and opens a draft pull
   request.
5. does the first switch on the machine itself, follows it live, and checks
   `coeusd` answers over the tailnet afterwards. a new mac gets
   `tailscale.enable = true;`, so that switch also signs it in to the tailnet
   with the fleet's auth key.
6. marks the pull request ready. merge it, and the next deploy tells every
   other machine about the new one.

what goes into `hosts/<name>/` and which secrets it gets is decided by
`.coeus/bootstrap.nix`, not by coeus, so changing what a new host looks like
means editing that file. stopping it halfway is fine: running the same command
again picks up where it left off. on a mac, finish with `coeus doctor --fix`
(see [coeus](#coeus)).

## dns

cloudflare dns lives next to the services that need it: each name is a
`cloudflare.dns` entry in the module of the service that answers it, on the
machine that serves it, and [norn](https://github.com/GustavoWidman/norn)
keeps cloudflare in line with that. two machines claiming the same name, or a
`CNAME` sharing a name with anything, fails the build.

how far norn goes is up to each server's `services.norn.mode`. `report`
only logs what it would change, `adopt` also claims the records that already
match by writing norn's mark into their comment, and `enforce` creates,
updates and deletes as well. norn runs on every switch and every 15 minutes
after. on a server, `sudo norn report` prints the plan by hand and
`sudo norn status` says how the last run went.

## custom flakes

this repository pulls in a bunch of project and tool flakes directly from
github, including `coeus`, `norn`, `heimdall`, `rocky-bot`,
`kemono-pinger`, `portfolio`, `oxi`, `niks3`, `kache`, `taproot`, `copyparty`,
`upstreamer`, and a custom autobuild of `zed`. each one's module is imported only
by the machine that runs it; `lib/system.nix` lists the few every machine gets,
and `modules/server/upstreamer.nix` gives every server upstreamer, the reverse
proxy in front of all their sites.

nix builds what it needs, caches what it can, and still occasionally finds a way
to make me stare at a terminal for 40 minutes. tradition matters.

---

don't copy my code blindly. you will break your machine. read it, understand it,
and steal the parts that don't suck.
