_: self: _:
let
  inherit (self)
    attrNames
    concatMap
    filterAttrs
    fleet
    foldl'
    mapAttrs
    pathExists
    readDir
    ;

  # every machine that has a tailnet address; the others wait for one
  machines =
    fleet
    |> filterAttrs (_: machine: machine.address or null != null)
    |> mapAttrs (
      _: machine: {
        os = machine.class;
        alwaysOn = machine.type != "desktop";
        inherit (machine) address;
      }
    );

  # hosts/<host>/<service>/phoebe.nix, as { name = service; value = entry; }
  declared =
    host:
    readDir ../hosts/${host}
    |> filterAttrs (
      service: type: type == "directory" && pathExists ../hosts/${host}/${service}/phoebe.nix
    )
    |> attrNames
    |> map (service: {
      name = service;
      value = import ../hosts/${host}/${service}/phoebe.nix // {
        machine = host;
      };
    });
in
{
  # phoebe's registry of the fleet, `services.phoebe.fleet`. it is read from
  # each host's metadata and the phoebe.nix beside each service, never from a
  # machine's configuration, so every machine builds the same one on its own
  phoebeFleet = {
    inherit machines;

    nodes = machines |> filterAttrs (name: _: self.servesCoeusWeb fleet.${name}) |> attrNames;

    services =
      attrNames machines
      |> concatMap declared
      |> foldl' (
        services: service:
        if services ? ${service.name} then
          throw "phoebe: hosts/${services.${service.name}.machine}/${service.name} and hosts/${service.value.machine}/${service.name} both declare ${service.name}; service names are fleet-wide"
        else
          services // { ${service.name} = service.value; }
      ) { };
  };
}
