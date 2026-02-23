# r3dlust's nix config collection

my entire digital life, codified and trapped in a repository.

this repository manages the configuration for all my machines (macos, nixos, servers, vms). it is fully declarative, which means i never have to configure a new machine manually again. i run one command and everything from ssh keys to window managers just works.

## infrastructure overview

i currently manage 6 different hosts through this flake:

- **`laptop-mac`** (darwin, aarch64): my daily driver macbook. runs aerospace for window tiling, ghostty for terminal, and custom nushell scripts.
- **`desktop-nixos`** (nixos, x86_64): my main linux desktop. runs hyprland, wayland, and all the gaming/heavy lifting stuff (UNFINISHED, hyprland still needs configuration).
- **`home-vm`** (nixos, x86_64): a local dev server virtual machine (runs on my windows desktop when i'm too lazy to switch to linux).
- **`lab`** (nixos, x86_64): a remote dev server that runs at my home 24/7. i ssh into it from anywhere (using tailscale) and it has all my development tools and files.
- **`oracle-2`** (nixos, aarch64): a powerful oracle cloud server, handles backend routing and serves most of my personal projects that need to be online and on the public internet. fun fact, there *is* a `oracle-1`, i just haven't ported everything from it over to nix yet, so it's still running arch with a very light load. one day i'll finish porting everything over and put nixos on it to split `oracle-2`'s load.
- **`oracle-xray`** (nixos, x86_64): another oracle cloud server, this one is much smaller but i take advantage of it's great bandwidth for setting up proxy servers and subnet routing (it offers a IPv6 subnet for all my other machines, which enables IPv6 for when i'm on a network that doesn't support it, like my university's wifi).

## deployment

deployments are handled by `deploy.nu`, a nushell script i wrote because writing bash in 2026 should be considered a war crime. it uses `nh` under the hood for local builds and handles remote deployments via ssh seamlessly.

```bash
# rebuild the current machine
./deploy.nu

# rebuild a remote machine
./deploy.nu --remote lab

# rebuild all remotes sequentially
./deploy.nu all
```

fun fact: since my own shell loads a `.nu` file as a local toolchain, i actually use the `deploy.nu` script simply as `deploy`:

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
├── flake.nix        # the entry point. ties inputs, hosts, and lib together
├── hosts/           # machine-specific configurations
│   ├── desktop-nixos/
│   ├── laptop-mac/
│   └── ...
├── modules/         # shared configuration snippets
│   ├── common/      # stuff every machine gets (git, nushell, ssh, direnv)
│   ├── desktop/     # gui stuff (ghostty, fonts)
│   ├── dev/         # developer tools (rust, bun, zed, libraries)
│   ├── linux/       # linux-only modules (hyprland, docker, kernel tweaks)
│   ├── macos/       # macos-only modules (aerospace, homebrew, karabiner)
│   └── server/      # server-only modules (acme config)
├── lib/             # custom nix helper functions
│   ├── system.nix   # handles assembling the final machine configuration
│   └── values.nix   # various utility functions
└── deploy.nu        # deployment orchestrator
```

## code helpers & `lib`

the `lib/` directory is where the magic happens, it's heavily inspired off of rgbcube/ncc's `lib` module. instead of copy-pasting massive configurations for each host, `lib/system.nix` exports builder functions like `linuxDesktopSystem`, `linuxServerSystem`, and `darwinDesktopSystem`.

when a new host is defined in `hosts/my-host/flake.nix`, it calls one of these builder functions. the function automatically scoops up all the modules from `modules/common`, plus `modules/linux` (if it's linux), plus `modules/desktop` (if it's a desktop), injects all the overlays, and spits out a fully formed nixos or darwin configuration.

it makes spinning up a new machine literally as easy as creating a new folder, writing 20 lines of code, and running the deploy script.

## secrets

secrets are handled by `agenix`. public keys for each machine are stored in `keys.nix`, and the encrypted secrets are defined in `secrets.nix` e managed via age. `deploy.nu` has a helper to automatically fetch and inject a new machine's ed25519 host key into the `keys.nix` file during the initial deployment.

## initializing a new host

1. create a new folder in `hosts/`: `mkdir hosts/my-new-host`
2. create a `flake.nix` inside it, declaring the `metadata` (hostname, class, type, architecture).
3. call the appropriate lib function (e.g. `inputs.lib.linuxServerSystem inputs ({ config, lib, ... }: { ... })`)
4. run `deploy.nu --remote my-new-host --initial`
4.1. you'll likely have to add the new host's public key to `keys.nix` for the first deployment attempt, since it won't be there yet. the `deploy.nu` script should do this automatically, but rekeying might be necessary. once secrets for the new host are properly set up, run the *initial* deployment script again for the final configuration to be applied.
5. grab a coffee while nix does it's thing

## custom flakes

this repository pulls in a bunch of my own custom flakes directly from github, like `kemono-pinger`, `gemini-juggler`, `telegram-fwd`, `portfolio`, and a custom autobuild of `zed`. nix automatically builds and caches these for my machines to avoid waiting 40 minutes every time zed nightly updates.

---

don't copy my code blindly. you will break your machine. read it, understand it, and steal the parts that don't suck.
