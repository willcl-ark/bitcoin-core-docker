{
  description = "Bitcoin Core Docker images - aggregated from version-specific flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    bitcoin-30-0rc1.url = "path:./30.0rc1";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    bitcoin-30-0rc1,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      versionFlakes = [
        bitcoin-30-0rc1
      ];

      # Combine all packages from version flakes
      allPackages =
        nixpkgs.lib.foldl (
          acc: flake:
            acc // flake.packages.${system}
        ) {}
        versionFlakes;
    in {
      packages =
        allPackages
        // {
          default = bitcoin-30-0rc1.packages.${system}.default;
        };

      formatter = nixpkgs.legacyPackages.${system}.alejandra;
      devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          nix
          docker
          git
        ];
      };
    });
}
