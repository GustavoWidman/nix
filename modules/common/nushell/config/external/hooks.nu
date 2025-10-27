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
                | par-each { get name | path parse }
                | where {|el| ($el | get extension) == "nu" }
                | par-each {|el|
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
                | par-each { get name | path parse }
                | where {|el| ($el | get extension) == "nu" }
                | par-each {|el|
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
   	# direnv
	{||
	    direnv export json | from json | default {} | load-env
		$env.PATH = $env.PATH | split row (char env_sep)
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
$env.config.completions.external.completer = {|spans|
  # if the current command is an alias, get it's expansion
  let expanded_alias = (scope aliases | where name == $spans.0 | get -o 0 | get -o expansion)

  # overwrite
  let spans = (if $expanded_alias != null  {
    # put the first word of the expanded alias first in the span
    $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
  } else {
    $spans | skip 1 | prepend ($spans.0)
  })

  carapace $spans.0 nushell ...$spans
    | from json
}
