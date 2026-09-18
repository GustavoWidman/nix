{
  services.github-runners.thoth-lab = {
    enable = true;
    url = "https://github.com/GustavoWidman/thoth";
    name = "lab";
    tokenFile = "/home/oracle/.github-runner-token";
    extraLabels = [ "nixos" "lab" "x86_64-linux" ];
    replace = true;
  };
}
