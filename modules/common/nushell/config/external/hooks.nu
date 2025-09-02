use ($nu.default-config-dir | path join "config/external/mise.nu")
use ($nu.default-config-dir | path join "config/external/zoxide.nu")

def find-jj-dir [pwd?: string] {
    mut current_dir = if ($pwd | is-empty) {
        pwd
    } else {
        $pwd
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
    },
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
    # Nu Environment (add and create symlinks for any local nu files to PATH)
    {
        condition: {|_, after| (ls $after err> /dev/null | where { get name | str ends-with ".nu" } | is-not-empty) }
        code: {|_, after|
            # Create symlinks to all nu files so we can reference "x.nu" as "x"
            let nudir = ($after | path join ".nu")
            if not ($nudir | path exists) {
                mkdir ($nudir | path join "bin")
            }

            ls $after err> /dev/null
                | where { get name | str ends-with ".nu" }
                | par-each {|el|
                    let file = ($el | get name | path expand)
                    let symlink = ($nudir | path join "bin" | path join ($el | get name | path parse | get stem))
                    if ((not ($symlink | path exists)) or ((readlink $symlink) != $file)) {
                        ln -s $file ($symlink | path expand)
                    }
                }

            $env.PATH = (
               	$env.PATH
              		| prepend ($nudir | path join "bin")
              		| uniq
            )
        }
    },
    {
        condition: {|before, _|
            (($before | is-not-empty) and (ls $before err> /dev/null | where { get name | str ends-with ".nu" } | is-not-empty))
        }
        code: {|before, _|
            $env.PATH = (
               	$env.PATH
              		| where $it != ($before | path join ".nu" "bin")
              		| uniq
            )
        }
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
