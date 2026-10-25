{ config, pkgs, ... }:

let
  # The upstream 10.21.2 images still contain Node 24.22.0/20.x.
  # Run both components with the patched, ABI-compatible Node 24 runtime.
  # CVE-2026-111497: https://nodejs.org/en/blog/vulnerability/october-2026-security-releases
  node = pkgs.stdenvNoCC.mkDerivation {
    pname = "mcsmanager-nodejs";
    version = "24.22.1";
    src = pkgs.fetchurl {
      url = "https://nodejs.org/dist/v24.22.1/node-v24.22.1-linux-arm64.tar.xz";
      hash = "sha256-26v3ocv5R+YFn/rSwnuABB25feoeVTtir97n8T/KM24=";
    };
    nativeBuildInputs = [ pkgs.patchelf ];
    # patchelf's default section sorting corrupts this upstream ARM64 ELF.
    # Keep its layout and patch explicitly; both Alpine and glibc images then
    # use the same Nix-provided interpreter and libraries via useHostStore.
    dontFixup = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 bin/node $out/bin/node
      patchelf --no-sort \
        --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
        --set-rpath ${
          pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.stdenv.cc.cc.libgcc
          ]
        } \
        $out/bin/node
      runHook postInstall
    '';
    meta.platforms = [ "aarch64-linux" ];
  };
in
{
  system.build.mcsmanager-node = node;

  networking.certificates."minecraft.r3dlust.com" = {
    enable = true;
    group = "caddy-certs";
    users = [
      "caddy"
    ];

    postRun = ''
      systemctl reload-or-restart caddy.service
    '';
  };

  virtualisation.arion.projects.mcsmanager.settings = {
    services = {
      web.service = {
        # Panel 10.21.2 / daemon 4.19.2; immutable multi-architecture manifests.
        image = "githubyumao/mcsmanager-web@sha256:2595f44584cd8e6878ec016c7c82cf4dd73b8c3de6ab44998652fb1ae5375341";
        useHostStore = true;
        command = [
          "${node}/bin/node"
          "--max-old-space-size=8192"
          "app.js"
        ];
        environment.PATH = "${node}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
        restart = "unless-stopped";
        ports = [ "127.0.0.1:27613:23333" ];
        volumes = [
          "/var/lib/mcsmanager/web/data:/opt/mcsmanager/web/data"
          "/var/lib/mcsmanager/web/logs:/opt/mcsmanager/web/logs"
          "/etc/localtime:/etc/localtime:ro"
        ];
      };

      daemon.service = {
        image = "githubyumao/mcsmanager-daemon@sha256:6e7bbe3f3c8826642717f0de4a3f2cdf42af40a0740b1b4bf6e6301a3c29d3f3";
        useHostStore = true;
        command = [
          "${node}/bin/node"
          "--max-old-space-size=8192"
          "app.js"
        ];
        restart = "unless-stopped";
        ports = [
          "127.0.0.1:52930:24444"
          "25565:25565"
          "25566:25566"
        ];
        environment = {
          PATH = "${node}/bin:/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
          MCSM_DOCKER_WORKSPACE_PATH = "/var/lib/mcsmanager/daemon/data/InstanceData";
        };
        volumes = [
          "/var/lib/mcsmanager/daemon/data:/opt/mcsmanager/daemon/data"
          "/var/lib/mcsmanager/daemon/logs:/opt/mcsmanager/daemon/logs"
          "/etc/localtime:/etc/localtime:ro"
          "/var/run/docker.sock:/var/run/docker.sock"
        ];
      };
    };
  };

  networking.firewall = {
    allowedUDPPorts = [
      25565
      25566
      25567
    ];
    allowedTCPPorts = [
      25565
      25566
      25567
    ];
  };

  services.caddy.virtualHosts."minecraft.r3dlust.com" = {
    extraConfig = ''
      ${config.networking.certificates."minecraft.r3dlust.com".paths.caddy}

      handle_path /daemon/* {
        reverse_proxy http://127.0.0.1:52930
      }

      handle {
        reverse_proxy /* {
          to http://127.0.0.1:27613
        }
      }
    '';
  };
}
