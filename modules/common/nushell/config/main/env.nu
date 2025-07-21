export def --wrapped main [...args] {
	let out = (^env ...$args | complete)

	if $out.exit_code != 0 {
		error make -u {
			msg: $"(absolute env) encountered and error while running:"
			label: {
				text: ($out.stderr | str replace -a $'(absolute env): ' '' | str trim)
				span: (metadata $args | get span)
			}
		}
	}

	if $out.stdout =~ '^(?:(?:[^\n=]+?)=(?:[^\n=]*)\n?)+$' {
		try {
            $out.stdout | lines | parse "{key}={val}" | transpose -r | into record
        } catch {
            $out.stdout
        }
	} else {
		$out.stdout
	}
}
