def fish-completer [spans: list<string>] {
	^fish --command $"complete '--do-complete=($spans | str replace --all "'" "\\'" | str join ' ')'"
	| from tsv --flexible --noheaders --no-infer
	| rename value description
	| update value {|row|
		let value = $row.value
		let need_quote = ['\' ',' '[' ']' '(' ')' ' ' '\t' "'" '"' "`"] | any { $in in $value }
		if ($need_quote and ($value | path exists)) {
			let expanded_path = if ($value starts-with ~) { $value | path expand --no-symlink } else { $value }
			$'"($expanded_path | str replace --all "\"" "\\\"")"'
		} else { $value }
	}
}

@complete fish-completer
extern "nix shell" []
