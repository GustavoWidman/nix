use ($nu.default-config-dir | path join config/main/prompt.nu)
use ($nu.default-config-dir | path join config/main/sudo.nu)
use ($nu.default-config-dir | path join config/external/mise.nu)
use ($nu.default-config-dir | path join config/utils/hooks.nu)
source ($nu.default-config-dir | path join config/external/zoxide.nu)
source ($nu.default-config-dir | path join config/external/carapace.nu)

if $env.OS == "Darwin" {
	hooks run-hooked $'source `($nu.default-config-dir | path join config/macos/aliases.nu)`'
	hooks run-hooked $'source `($nu.default-config-dir | path join config/macos/utm.nu)`'
	hooks run-hooked $'source `($nu.default-config-dir | path join config/macos/wg.nu)`'

	hooks run-hooked $'use `($nu.default-config-dir | path join config/macos/lsblk.nu)`'
}