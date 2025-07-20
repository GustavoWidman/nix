$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'

if not ($"($env.TRUE_HOME)/.cache/carapace" | path exists) {
	mkdir $"($env.TRUE_HOME)/.cache/carapace"
}