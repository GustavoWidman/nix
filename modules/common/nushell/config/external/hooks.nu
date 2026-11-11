use mise.nu
use zoxide.nu

def find-jj-dir [pwd?: string] {
    mut current_dir = match ($pwd | is-empty) {
        true => (pwd),
        false => $pwd
    }

    loop {
        let jj_path = ($current_dir | path join ".jj")

        if ($jj_path | path exists) {
            return ($jj_path | path dirname)
        }

        let parent = ($current_dir | path dirname)
        if $parent == $current_dir {
            return ""
        }
        $current_dir = $parent
    }
}

$env.config.hooks.env_change.PWD = [
	# Zoxide
	{
		__zoxide_hook: true,
		code: {|_, dir| zoxide add -- $dir}
	},
	# Mise
	{
		condition: { "MISE_SHELL" in $env }
		code: { mise hook }
	}
    # Rust Environment (add and remove debug and release builds to PATH)
    {
		condition: {|_, after| ($after | path join 'Cargo.lock' | path exists) }
		code: {|_, after|
			$env.PATH = (
				$env.PATH
					| prepend ($after | path join 'target' 'debug')
					| prepend ($after | path join 'target' 'release')
					| uniq
			)
		}
	},
	{
		condition: {|before, _| ($before | default '' | path join 'Cargo.lock' | path exists) and ($before | is-not-empty)}
		code: {|before, _|
			$env.PATH = (
				$env.PATH
					| where $it != ($before | path join 'target' 'debug')
					| where $it != ($before | path join 'target' 'release')
					| uniq
			)
		}
	}
	# Nix Environment (add and remove result/bin to PATH)
    {
        condition: {|_, after| ($after | path join 'flake.lock' | path exists) }
        code: {|_, after|
            $env.PATH = (
               	$env.PATH
              		| prepend ($after | path join 'result' 'bin')
              		| uniq
            )
        }
    }
    {
        condition: {|before, _| ($before | default '' | path join 'flake.lock' | path exists) and ($before | is-not-empty)}
        code: {|before, _|
            $env.PATH = (
               	$env.PATH
              		| where $it != ($before | path join 'result' 'bin')
              		| uniq
            )
        }
    }
    # nu
    {
        condition: {
            let nu_files = ls -a err> /dev/null
                | where {|el| ($el | get type) == "file" }
                | each { get name | path parse }
                | where {|el| ($el | get extension) == "nu" }
                | each {|el|
                    let path = (pwd | path join $"($el.stem).($el.extension)")
                    {
                        stem: $el.stem
                        hash: (open $path | hash sha256),
                        path: $path
                    }
                }

            # stops if we have 0 or +1 nu file in pwd
            if ($nu_files | is-empty) or (($nu_files | length) > 1) {
                return false
            };

            let env_hash = $nu_files
                | get hash
                | str join "\n"
                | hash sha256

           	if (("NU_ENV" in $env) and $env.NU_ENV != null) {
               	if ($env_hash == ($env.NU_ENV | get hash)) {
                    # already EXACTLY activated
                    return false
               	} else {
                    # other is activated
                    return true
                }
           	} else {
                # not activated
                return true
            }
        }
        code: 'nu activate -q'
    },
    {
        condition: {
            let activated = ("NU_ENV" in $env) and ($env.NU_ENV != null)

            if not $activated {
                return false
            }

            let nu_files = ls -a err> /dev/null
                | where {|el| ($el | get type) == "file" }
                | each { get name | path parse }
                | where {|el| ($el | get extension) == "nu" }
                | each {|el|
                    let path = (pwd | path join $"($el.stem).($el.extension)")
                    {
                        stem: $el.stem
                        hash: (open $path | hash sha256),
                        path: $path
                    }
                }

            ($nu_files | is-empty)
        }
        code: 'nu deactivate -q'
    }
];

$env.config.hooks.pre_prompt = [
	# Mise
	{
		condition: { "MISE_SHELL" in $env }
		code: { mise hook }
	}
];

alias cd = zoxide z
alias cdi = zoxide zi

$env.config.completions.external.enable = true
# nushell runs ordinary completers on a background worker, and reedline only checks for
# its answer every 100 ms, so each Tab waited for that tick. A completer whose closure ends
# in an @interactive command runs inline on the line editor thread instead.
@interactive
def carapace-complete [place: record] {
  carapace $place.command.0 nushell ...$place.command
    | from json
}

$env.config.completions.external.completer = {|place| carapace-complete $place }
