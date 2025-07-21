$env.CARAPACE_BRIDGES = 'inshellisense,carapace,fish,zsh,bash'

if not ($"($env.TRUE_HOME)/.cache/carapace" | path exists) {
	mkdir $"($env.TRUE_HOME)/.cache/carapace"
}