export def --env main [] {
	if (ls | where name == flake.nix | is-not-empty) {
	    print $"[(ansi yellow)mkdevshell::flake(ansi reset)]	There already seems to be a flake.nix file in the current directory."
        let choice = input -n 1 -s $"			Are you sure you want to continue? \((ansi green)y(ansi reset)/(ansi red)n(ansi reset)\): "
        print "" # newline
        if ($choice | str downcase) != "y" {
            if ($choice | str downcase) != "n" {
                print $"[(ansi yellow)mkdevshell:invalid_choice(ansi reset)]	Invalid choice, exiting..."
            } else {
                print $"[(ansi red)mkdevshell:exit(ansi reset)]	Exiting without making any changes..."
            }
            return
        };
	}

	let template_file = '
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {

        };
      }
    );
}
' | str trim

    $template_file | save -f flake.nix

    print $"[(ansi green)mkdevshell:success(ansi reset)]	Successfully created (ansi cyan)flake.nix(ansi reset) file in the current directory"
    print $"			You can now run `(ansi cyan)dev(ansi reset)` or `(ansi cyan)devshell(ansi reset)` to enter the development shell"
}
