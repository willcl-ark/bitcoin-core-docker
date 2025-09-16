{
  description = "Bitcoin Core 30.0rc1 Docker images";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      common = import ../common.nix {
        inherit nixpkgs flake-utils system;
      };

      shasumsLib = import ../shasums.nix {
        inherit nixpkgs system;
      };

      versions = {
        "30.0rc1" = shasumsLib.shasumsToVersionConfig {
          version = "30.0rc1";
          urlPath = "bitcoin-core-30.0/test.rc1/";
          tags = ["30.0rc1"];
          shasumsPath = ./SHA256SUMS;
        };
      };

      self' =
        common
        // {
          packages = common.generatePackages self' versions;
        };
    in {
      packages =
        self'.packages
        // {
          default = common.mkBitcoinDockerImage self' versions."30.0rc1" system "30.0rc1";
        };

      formatter = nixpkgs.legacyPackages.${system}.alejandra;
    });
}
