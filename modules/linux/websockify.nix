{ ... }:

{
  nixpkgs.overlays = [
    (_: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_: pythonPrev: {
          websockify = pythonPrev.websockify.overridePythonAttrs (old: {
            # jwcrypto 1.5.8 now correctly enforces HS256's 256-bit minimum.
            # websockify 0.13.0's public TEST fixture decodes to only 72 bits.
            # Replace the fixture, not the security check; keep all tests enabled.
            postPatch = (old.postPatch or "") + ''
              substituteInPlace tests/fixtures/symmetric.key \
                --replace-fail secret_sauce MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY
            '';
          });
        })
      ];
    })
  ];
}
