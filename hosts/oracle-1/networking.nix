{
  networking.interfaces.enp0s6 = {
    useDHCP = true;

    ipv4.addresses = [
      {
        address = "10.0.0.200";
        prefixLength = 24;
      }
    ];
  };
}
