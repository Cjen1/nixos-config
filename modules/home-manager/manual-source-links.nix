{ ... }:
{
  nixpkgs.overlays = [
    (_final: prev: {
      nixosOptionsDoc =
        args:
        prev.nixosOptionsDoc (
          args
          // {
            transformOptions =
              option:
              let
                transformed = (args.transformOptions or (value: value)) option;
                source = "modules/generic/meta-maintainers.nix";
              in
              transformed
              // {
                # Home Manager 26.05 leaves this imported declaration as an
                # untracked store path in options.json.
                declarations = map (
                  declaration:
                  if builtins.isString declaration && prev.lib.hasSuffix "/${source}" declaration then
                    {
                      name = "<nixpkgs/${source}>";
                      url = "https://github.com/NixOS/nixpkgs/blob/nixos-26.05/${source}";
                    }
                  else
                    declaration
                ) transformed.declarations;
              };
          }
        );
    })
  ];
}
