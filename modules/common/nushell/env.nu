use config/utils/cache.nu
use config/utils/ports.nu
use config/utils/init.nu

$env.config.show_banner = false
$env.VIRTUAL_ENV_DISABLE_PROMPT = true
$env.OS = uname | get operating-system
$env.HOSTNAME = cache get_hostname
$env.config.buffer_editor = "nano"
$env.TRUE_HOME = cache true_home
$env.USER_COLOR = init init_user_color
$env.EDITOR = "nano"

$env.config.history.isolation = true;
$env.config.history.file_format = "sqlite";

init init_gitconfig

$env.BUN_INSTALL = $"($env.TRUE_HOME)/.bun"
mut path = [
	"/nix/var/nix/profiles/default/bin/",
	$"($env.TRUE_HOME)/.nix-profile/bin/",
	"/run/current-system/sw/bin",
	$"($env.TRUE_HOME)/.nix-profile/bin",
	$"/etc/profiles/per-user/($env.USER)/bin",
	$"($env.BUN_INSTALL)/bin",
	$"($env.TRUE_HOME)/.local/bin",
	$"($env.TRUE_HOME)/.cargo/bin"
	$"($env.TRUE_HOME)/go/bin",
	"/usr/local/bin",
	$"($env.TRUE_HOME)/.cabal/bin",
	$"($env.TRUE_HOME)/.ghcup/bin",
]

if $env.OS == "Darwin" {
	# Cache Homebrew environment variables and only update weekly
	cache brew_env 7 | load-env

	$env.PNPM_HOME = $env.TRUE_HOME + "/Library/pnpm"


	$path ++= [
		"/opt/homebrew/opt/util-linux/bin",
		"/opt/homebrew/opt/util-linux/sbin"
		"/Applications/UTM.app/Contents/MacOS",
		"/opt/homebrew/opt/e2fsprogs/bin",
		"/opt/homebrew/opt/e2fsprogs/sbin",
		"/opt/homebrew/opt/llvm/bin",
		"/opt/metasploit-framework/bin",
		"/opt/homebrew/Cellar/john-jumbo/1.9.0_1/share/john",
		$env.PNPM_HOME
	]

	$env.HOMEBREW_NO_ENV_HINTS = true

	$env.LDFLAGS = "-L/opt/homebrew/opt/llvm/lib"
  	$env.CPPFLAGS = "-I/opt/homebrew/opt/llvm/include"
}

$env.PATH = ($path | append ($env.PATH | split row (char esep)))

init full_init

source config/main/aliases.nu
source config/main/carapace.nu
use config/misc/hackingclub.nu
