_: _: _: {
  fetchGitFlake =
    {
      owner,
      repo,
      ssh ? false,
      tag ? null,
      rev ? null,
    }:
    let
      url =
        if ssh then
          if tag != null then
            "git+ssh://git@github.com/${owner}/${repo}?ref=${tag}"
          else if rev != null then
            "git+ssh://git@github.com/${owner}/${repo}?rev=${rev}"
          else
            "git+ssh://git@github.com/${owner}/${repo}"
        else if tag != null then
          "github:${owner}/${repo}/${tag}"
        else if rev != null then
          "github:${owner}/${repo}/${rev}"
        else
          "github:${owner}/${repo}";
    in
    builtins.getFlake url;
}
