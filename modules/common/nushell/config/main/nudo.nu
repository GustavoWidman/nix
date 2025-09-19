def "nu-complete nudo" [commandline: string] {
	let spans = ($commandline | split row " " | skip 1)

	if ($spans | length) <= 1 {
		let external_commands = ($env.PATH
			| split row (char esep)
			| each {|path|
				try {
					ls $path
					| where type == file
					| get name
					| path basename
				} catch { [] }
			}
			| flatten
			| uniq
			| each {|cmd| {name: $cmd, description: ""}})

		let builtin_commands = (scope commands | select name description)
		let aliases = (scope aliases | select name description)

		let all_commands = ($builtin_commands
			| append $external_commands
			| append $aliases
			| uniq-by name)

		let partial = if ($spans | length) == 1 { $spans.0 } else { "" }

        return ($all_commands
        | where {|cmd| $cmd.name | str starts-with $partial}
        | par-each -k {|cmd| {value: $cmd.name, description: $cmd.description}})

    }

	let expanded_alias = (scope aliases | where name == $spans.0 | get -o 0 | get -o expansion)

	# overwrite
	let spans = (if $expanded_alias != null  {
		# put the first word of the expanded alias first in the span
		$spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
	} else {
		$spans | skip 1 | prepend ($spans.0)
	})


	return (carapace $spans.0 nushell ...$spans
		| from json)
}

export def --wrapped --env main [...rest: string@"nu-complete nudo"] {
    let args = $rest | str join " "
    sudo nu -c $args
}
