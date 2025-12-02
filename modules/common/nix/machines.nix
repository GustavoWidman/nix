{
  config,
  self,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    attrsToList
    filter
    length
    ;

  machinesList =
    self.machineMetadata
    |> attrsToList
    |> filter (
      { name, value }: (name != config.networking.hostName) && (length value.build-architectures > 0)
    )
    |> map (
      { name, value }:
      let
        systems = concatStringsSep "," value.build-architectures;
        key = config.secrets.ssh-misc-build.path;
        features = concatStringsSep "," [
          "benchmark"
          "big-parallel"
          "kvm"
          "nixos-test"
        ];
      in
      "ssh-ng://build@${name} ${systems} ${key} 20 1 ${features} - -"
    );
in
{
  environment.etc."nix/machines".text = concatStringsSep "\n" machinesList;
}
