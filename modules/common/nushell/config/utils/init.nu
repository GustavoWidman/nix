export def --env init_user_color () {
	if not (($"($env.TRUE_HOME)/.user_color" | path exists)) {
		# prompt user for a valid color
		mut color = ""
		while $color == "" {
			let user_input = input $"(ansi light_gray)[(ansi reset)(ansi green_bold)+(ansi reset)(ansi light_gray)](ansi reset) Enter the user color you would like to use for this machine \(e.g. (ansi red)red(ansi reset), (ansi blue)blue(ansi reset), (ansi green)green(ansi reset)\): " | str trim
			# try to parse as a ascii color
			try {
				ansi $user_input

				$color = $user_input
			} catch {
				print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Please enter a valid color name.(ansi reset)\n"
			}
		}

		# save $env.USER_COLOR: $color record to a file
		$color | save -f $"($env.TRUE_HOME)/.user_color"
	}

	# load the user color from the file
	return (open $"($env.TRUE_HOME)/.user_color" | str trim) | default "red"
}