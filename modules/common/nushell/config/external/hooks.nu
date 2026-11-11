use mise.nu
use ../utils/paths.nu in-tree-of
use zoxide.nu

# Whether any mise config applies here, so mise has something to watch between prompts.
def mise-configured []: nothing -> bool {
    let config_home = $env.XDG_CONFIG_HOME? | default ($env.HOME | path join .config)
    (
        ($env.MISE_ENV? | is-not-empty)
        or ($env.MISE_CONFIG_DIR? | is-not-empty)
        or ($env.MISE_GLOBAL_CONFIG_FILE? | is-not-empty)
        or ([/etc/mise ($config_home | path join mise)] | path exists | any { $in })
        or (in-tree-of [mise.toml mise.local.toml .mise.toml .mise.local.toml .tool-versions .mise mise .config/mise.toml .config/mise])
    )
}

$env.config.hooks.env_change.PWD = [
	# Zoxide only records the visit, so nothing has to wait for it
	{
		__zoxide_hook: true,
		code: {|_, dir| job spawn { zoxide add -- $dir } | ignore }
	},
	# Mise, where a config applies or something it loaded has to unload
	{
		condition: { ("MISE_SHELL" in $env) and (("__MISE_DIFF" in $env) or (mise-configured)) }
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

# Each external call from the prompt costs several milliseconds before the tool does any
# work. Between prompts mise only needs to run where a config can change, and direnv only
# acts where an .envrc applies or something it loaded has to unload.
$env.config.hooks.pre_prompt = [
	# Closing a terminal while a command runs sends the hangup to that command, so the shell
	# lives on without a terminal. nushell then cannot exit while any background job is alive
	# and loops at full CPU, so deliver the hangup it missed.
	{
		condition: { not (is-terminal --stdin) }
		code: { kill --signal 1 $nu.pid }
	}
	{
		condition: { ("MISE_SHELL" in $env) and (mise-configured) }
		code: { mise hook }
	}
	{
		condition: { ("DIRENV_DIR" in $env) or (in-tree-of [.envrc]) }
		code: {
			let direnv = ^direnv export json | from json --strict | default {}

			for key in ($direnv | columns) {
				if ($direnv | get $key) == null {
					hide-env --ignore-errors $key
				}
			}

			$direnv
				| items {|key, value|
					let value = do (
						{
							"PATH": {
								from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
								to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
							}
						}
						| merge ($env.ENV_CONVERSIONS? | default {})
						| get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
						| if ($in | is-empty) { {|x| $x} } else { $in }
					) $value
					return [ $key $value ]
				}
				| where {|pair| $pair.1 != null }
				| into record
				| load-env
		}
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
