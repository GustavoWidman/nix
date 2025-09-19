use "config/main/prompt.nu"
use "config/main/absolute.nu"
use "config/main/mkdevshell.nu"
use "config/main/activate.nu"
use "config/main/nudo.nu"
use "config/main/env.nu"

use "config/utils/hooks.nu"

source "config/external/hooks.nu"


# very sad that i have to do this,
# but unfortunately nushell does not support
# conditional source/use of files.
if $env.OS == "Darwin" {
    hooks run-hooked $'source `($nu.default-config-dir | path join "config/macos/aliases.nu")`'

	hooks run-hooked $'use `($nu.default-config-dir | path join "config/macos/wg.nu")`'
	hooks run-hooked $'use `($nu.default-config-dir | path join "config/macos/utm.nu")`'
	hooks run-hooked $'use `($nu.default-config-dir | path join "config/macos/lsblk.nu")`'
}
