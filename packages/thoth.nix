{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_22,
  src ? null,
  npmDepsHash ? "sha256-lIqh5Rd0MoT/MJ7oph4XeCO0xVfLvCtaahBX03s4ZPc=",
  primeAgent ? null,
}:
assert lib.assertMsg (src != null) ''
  Thoth is not bundled with this flake. Set `src` to a fixed-output Prime Agent
  AIO source input when calling packages/thoth.nix.
'';
assert lib.assertMsg (npmDepsHash != null) ''
  Thoth needs the npmDepsHash for the pinned integrations/discord-bot/package-lock.json.
'';
assert lib.assertMsg (primeAgent != null) ''
  Thoth needs a reproducible Prime Agent package. The Discord integration declares
  Prime Agent as an optional peer dependency, but its public SDK is required at build
  and runtime. Pass a package derivation that exposes package.json at its root.
'';
assert lib.assertMsg (builtins.pathExists "${src}/integrations/discord-bot/package-lock.json") ''
  Thoth source is missing integrations/discord-bot/package-lock.json. Do not build
  from an unlocked npm tree.
'';

let
  packageJson = builtins.fromJSON (
    builtins.readFile "${src}/integrations/discord-bot/package.json"
  );
  version = packageJson.version;
  cleanSrc = lib.cleanSourceWith {
    inherit src;
    filter = path: type:
      let name = builtins.baseNameOf path;
      in name != ".git" && name != ".venv" && name != "node_modules";
  };
in
buildNpmPackage {
  pname = "thoth";
  inherit version npmDepsHash;
  src = cleanSrc;

  nodejs = nodejs_22;
  npmRoot = "integrations/discord-bot";
  dontNpmBuild = true;

  # The integration is a nested package. The generic npm build hook runs from
  # the repository root, so invoke its locked build explicitly.
  buildPhase = ''
    runHook preBuild
    cd integrations/discord-bot
    npm run build
    cd ../..
    runHook postBuild
  '';

  # Keep the repository root compatible with nixpkgs' dependency hook while the
  # actual npm build remains scoped to the nested integration package.
  postPatch = ''
    cp integrations/discord-bot/package-lock.json package-lock.json
  '';

  nativeBuildInputs = [ makeWrapper ];

  # Prime Agent is a separate pinned package input, but it is copied into the
  # Thoth closure. Runtime startup never consults host-global npm state.
  preBuild = ''
    cd integrations/discord-bot
    ln -s ${lib.escapeShellArg primeAgent} node_modules/prime-agent
    cd ../..
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/thoth" "$out/share/thoth/agent"
    cp -a integrations/discord-bot/dist "$out/libexec/thoth/dist"
    # The development tree contains a Prime Agent staging symlink. Dereference
    # it so the installed runtime is self-contained and passes Thoth's bundle
    # boundary check without consulting host-global npm state.
    cp -aL integrations/discord-bot/node_modules "$out/libexec/thoth/node_modules"
    cp -a integrations/discord-bot/package.json "$out/libexec/thoth/package.json"
    cp -a integrations/discord-bot/scripts/thoth-runtime.mjs "$out/bin/thoth-runtime.mjs"
    chmod 0755 "$out/bin/thoth-runtime.mjs"

    # These are the installed Prime Agent resources. Runtime state and auth stay
    # outside the store; the NixOS module links these resources into agentDir.
    cp -a extensions "$out/share/thoth/agent/extensions"
    cp -a skills "$out/share/thoth/agent/skills"

    # Thoth is the lifecycle root. The runtime boundary validates the bundle,
    # sets the bundled Prime Agent module path, then imports the daemon in this
    # same process so systemd can own the complete descendant tree.
    makeWrapper ${nodejs_22}/bin/node "$out/bin/thoth" \
      --add-flags "$out/bin/thoth-runtime.mjs" \
      --add-flags "launch" \
      --add-flags "--bundle $out/libexec/thoth"

    runHook postInstall
  '';

  passthru = {
    primeAgent = primeAgent;
    source = src;
  };
}
