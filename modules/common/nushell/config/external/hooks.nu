use ($nu.default-config-dir | path join "config/external/mise.nu")
use ($nu.default-config-dir | path join "config/external/zoxide.nu")

def find-git-dir [pwd?: string] {
    mut current_dir = if ($pwd | is-empty) {
        pwd
    } else {
        $pwd
    }

    loop {
        let git_path = ($current_dir | path join ".git")

        if ($git_path | path exists) {
            return $git_path
        }

        let parent = ($current_dir | path dirname)
        if $parent == $current_dir {
            # reached filesystem root
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
	# Git status cache
	{
        code: {|_, dir|
            let _ = job list
                | where {|job|
                    let tag = $job | get -o tag
                    let gitdir = find-git-dir $dir | str trim

                    return (($tag | str starts-with "git-status-cache") and ($tag != $"git-status-cache($gitdir | str replace -a "/" "-" | str downcase)")) }
                | each {|job| job kill $job.id}
        }
    },
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
