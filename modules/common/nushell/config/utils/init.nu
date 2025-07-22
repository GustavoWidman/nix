def --env init_rust_toolchain () {
	if not ($"($env.TRUE_HOME)/.cargo" | path exists) {
		try {
			let tmp = (mktemp -t --suffix ".sh" | str trim)
			/bin/bash -c $"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > ($tmp)
chmod +x ($tmp)
($tmp) -y
rm ($tmp)"
		} catch {
			print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Failed to install Rust toolchain. Please install it manually.(ansi reset)\n"
			return false
		}
	}


	if not (($"($env.TRUE_HOME)/.cargo/bin/cargo-binstall" | path exists) or ((which cargo-binstall | length) > 0)) {
		try { cargo install cargo-binstall --locked } catch {
			print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Failed to install zoxide. Please install it manually.(ansi reset)\n"
			return false
		}
	}

	return true
}

def --env init_uv () {
	if not (($"($env.TRUE_HOME)/.local/bin/uv" | path exists) or ((which uv | length) > 0)) {
		try { curl -LsSf https://astral.sh/uv/install.sh | sh } catch {
			print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Failed to install uv. Please install it manually.(ansi reset)\n"
			return false
		}
	}

	return true
}

def --env init_mise () {
	if not (($"($env.TRUE_HOME)/.local/bin/mise" | path exists) or ((which mise | length) > 0)) {
		try { curl https://mise.run/ | sh } catch {
			print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Failed to install mise. Please install it manually.(ansi reset)\n"
			return false
		}
	}

	return true
}

# REQUIRES RUST TOOLCHAIN
def --env init_zoxide () {
	if not (($"($env.TRUE_HOME)/.cargo/bin/zoxide" | path exists) or ((which zoxide | length) > 0)) {
		try { cargo-binstall zoxide --locked --no-confirm } catch {
			print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Failed to install zoxide. Please install it manually.(ansi reset)\n"
			return false
		}
	}

	return true
}

# REQUIRES RUST TOOLCHAIN
def --env init_bat () {
	if not (($"($env.TRUE_HOME)/.cargo/bin/bat" | path exists) or ((which bat | length) > 0)) {
		try { cargo-binstall bat --locked --no-confirm } catch {
			print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Failed to install bat. Please install it manually.(ansi reset)\n"
			return false
		}
	}

	return true
}

# REQUIRES RUST TOOLCHAIN
def --env init_plugins () {
	let plugins = plugin list;
	mut restart_required = false

	# gstat plugin
	if ((not ($"($env.TRUE_HOME)/.cargo/bin/nu_plugin_gstat" | path exists)) or ((plugin list | where name == gstat | length) == 0)) {
		try {
			cargo-binstall nu_plugin_gstat --locked --no-confirm
			plugin add $"($env.TRUE_HOME)/.cargo/bin/nu_plugin_gstat"

			$restart_required = true
		} catch {
			print $"(ansi light_gray)[(ansi reset)(ansi red_bold)!(ansi reset)(ansi light_gray)](ansi reset)(ansi red) Failed to install gstat plugin. Please install it manually.(ansi reset)\n"
			return false
		}
	}

	if $restart_required {
		exec nu
	}

	return true
}

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

export def --env full_init () {
	let ok_rust = init_rust_toolchain
	let ok_uv = init_uv
	let ok_mise = init_mise
	let ok_zoxide = init_zoxide
	let ok_bat = init_bat
	let ok_plugins = init_plugins

	return ($ok_rust and $ok_uv and $ok_mise and $ok_zoxide and $ok_bat and $ok_plugins)
}