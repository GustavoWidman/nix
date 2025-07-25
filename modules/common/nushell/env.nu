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
$env.HOME = if $env.USER == "root" {
  if $env.OS == "Darwin" {
    "/var/root"
  } else {
    "/root"
  }
} else {
  $env.TRUE_HOME
}

$env.EDITOR = "nano"
$env.PAGER = "bat --plain"
$env.MANPAGER = "bat --plain"

$env.config.history.isolation = true;
$env.config.history.file_format = "sqlite";
$env.config.history.max_size = 10_000_000

$env.config.recursion_limit = 100

$env.config.completions.algorithm = "substring"
$env.config.completions.sort = "smart"
$env.config.completions.case_sensitive = false
$env.config.completions.quick = true
$env.config.completions.partial = true
$env.config.completions.use_ls_colors = true

$env.config.bracketed_paste = true

$env.config.use_ansi_coloring = "auto"

$env.config.error_style = "fancy"

$env.config.highlight_resolved_externals = true

$env.config.display_errors.exit_code = false
$env.config.display_errors.termination_signal = true

$env.config.footer_mode = 25

$env.config.table.mode = "single"
$env.config.table.index_mode = "always"
$env.config.table.show_empty = true
$env.config.table.padding.left = 1
$env.config.table.padding.right = 1
$env.config.table.trim.methodology = "wrapping"
$env.config.table.trim.wrapping_try_keep_words = true
$env.config.table.trim.truncating_suffix =  "..."
$env.config.table.header_on_separator = true
$env.config.table.abbreviated_row_count = null
$env.config.table.footer_inheritance = true
$env.config.table.missing_value_symbol = $"(ansi magenta_bold)nope(ansi reset)"

$env.config.datetime_format.table = null
$env.config.datetime_format.normal = $"(ansi blue_bold)%Y(ansi reset)(ansi yellow)-(ansi blue_bold)%m(ansi reset)(ansi yellow)-(ansi blue_bold)%d(ansi reset)(ansi black)T(ansi magenta_bold)%H(ansi reset)(ansi yellow):(ansi magenta_bold)%M(ansi reset)(ansi yellow):(ansi magenta_bold)%S(ansi reset)"

$env.config.filesize.unit = "metric"
$env.config.filesize.show_unit = true
$env.config.filesize.precision = 1

$env.config.render_right_prompt_on_last_line = false

$env.config.float_precision = 2

$env.config.ls.use_ls_colors = true

let menus = [
  {
    name: completion_menu
    only_buffer_difference: false
    marker: $env.PROMPT_INDICATOR
    type: {
      layout: ide
      min_completion_width: 0
      max_completion_width: 150
      max_completion_height: 25
      padding: 0
      border: false
      cursor_offset: 0
      description_mode: "prefer_right"
      min_description_width: 0
      max_description_width: 50
      max_description_height: 10
      description_offset: 1
      correct_cursor_pos: true
    }
    style: {
      text: white
      selected_text: white_reverse
      description_text: yellow
      match_text: { attr: u }
      selected_match_text: { attr: ur }
    }
  }
  {
    name: history_menu
    only_buffer_difference: true
    marker: $env.PROMPT_INDICATOR
    type: {
      layout: list
      page_size: 10
    }
    style: {
      text: white
      selected_text: white_reverse
    }
  }
]

$env.config.menus = $env.config.menus
	| where name not-in ($menus | get name)
	| append $menus

$env.BUN_INSTALL = $"($env.TRUE_HOME)/.bun"
mut path = [
	"/nix/var/nix/profiles/default/bin/",
	$"($env.TRUE_HOME)/.nix-profile/bin/",
	"/run/current-system/sw/bin",
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
	let brew_env = cache brew_env 7

	$brew_env | reject PATH | load-env

	$env.PNPM_HOME = $env.TRUE_HOME + "/Library/pnpm"


	$path ++= [
		$env.PNPM_HOME
		...($brew_env | get PATH | split row (char esep))
	]

	$env.HOMEBREW_NO_ENV_HINTS = true

	$env.LDFLAGS = "-L/opt/homebrew/opt/llvm/lib"
  	$env.CPPFLAGS = "-I/opt/homebrew/opt/llvm/include"
} else {
  $path = $path | prepend "/run/wrappers/bin"
}

$env.PATH = ($path | append ($env.PATH | split row (char esep)))

source config/main/aliases.nu
source config/main/carapace.nu
use config/misc/hackingclub.nu
