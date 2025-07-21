def "nu-complete absolute" [commandline: string] {
	let program = ($commandline | split row " " | last)

	let commands = ($env.PATH
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
		| uniq)

	return ($commands
		| where {|cmd| $cmd | str starts-with $program}
		| par-each -k {|cmd| {value: $cmd, description: ""}})
}


export def main [
	program: string@"nu-complete absolute" 	# The program to find in PATH
	--all (-a) 								# List all possible paths
] {
	let out = which --all $program
		| where type == external
		| where {|row| $row.path | path exists}

	if ($out | is-empty) {
		error make -u {
			msg: "Unable to find absolute path"
			label: {
				text: $"Program '(ansi default_bold)(ansi default_underline)($program)(ansi reset)(ansi purple_bold)' not found in $env.PATH"
				span: (metadata $program | get span)
			}
		}
	}

	if $all {
		$out | get path | str join (char newline)
	} else {
		$out | get path | first
	}
}