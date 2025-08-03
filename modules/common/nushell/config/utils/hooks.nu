export def --env add-hook [field: cell-path new_hook: any] {
	let old_config = $env.config? | default {}
	let old_hooks = $old_config | get $field -o | default []
	$env.config = ($old_config | upsert $field ($old_hooks ++ [$new_hook]))
}

export def self-erasing-hook [...hook_lines: string] {
	let hook_id = random uuid

	# credits to https://github.com/dgroomes
	let ERASE_SNIPPET = $"let hooks = $env.config.hooks.pre_prompt; let filtered = $hooks | where not \( \($it | describe\) == \"string\" and \($it | str starts-with \"# ERASE ME ($hook_id)\")); $env.config.hooks.pre_prompt = $filtered"

	let snippet = [$"# ERASE ME ($hook_id)" ...$hook_lines $ERASE_SNIPPET] | str join (char newline)

	return $snippet
}

export def --env run-hooked [...hook_lines: string] {
	let hook = self-erasing-hook ...$hook_lines

	add-hook hooks.pre_prompt $hook
}
