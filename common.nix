{
  nixpkgs,
  system,
  ...
}: let
  pkgs = nixpkgs.legacyPackages.${system};

  # Extract targetPkgs logic to reuse in both functions
  getTargetPkgs = targetSystem:
    if targetSystem == system
    then pkgs # Native build
    else if targetSystem == "aarch64-linux"
    then pkgs.pkgsCross.aarch64-multiplatform
    else if targetSystem == "armv7l-linux"
    then pkgs.pkgsCross.armv7l-hf-multiplatform
    else if targetSystem == "x86_64-linux"
    then pkgs.pkgsCross.gnu64
    else if targetSystem == "powerpc64-linux"
    then pkgs.pkgsCross.ppc64
    else if targetSystem == "riscv64-linux"
    then pkgs.pkgsCross.riscv64
    else throw "Unsupported target: ${targetSystem}";
in {
  mkBitcoinCoreForPlatform = versionConfig: targetSystem: let
    targetPkgs = getTargetPkgs targetSystem;

    inherit (versionConfig) version;
    binaryConfig = versionConfig.binaries.${targetSystem} or (throw "Unsupported platform: ${targetSystem}");
    inherit (binaryConfig) platform;

    binaryTarball = pkgs.fetchurl {
      url = "https://bitcoincore.org/bin/${versionConfig.urlPath}bitcoin-${version}-${platform}.tar.gz";
      inherit (binaryConfig) hash;
    };
  in
    targetPkgs.stdenv.mkDerivation {
      pname = "bitcoin-core";
      inherit version;
      dontUnpack = true;

      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.autoPatchelfHook
      ];

      buildInputs = with targetPkgs; [
        stdenv.cc.cc.lib
        glibc
      ];

      # For PowerPC64, ignore missing ld64.so.1 since we'll provide it via symlink
      autoPatchelfIgnoreMissingDeps = pkgs.lib.optionals (targetSystem == "powerpc64-linux") [
        "ld64.so.1"
      ];

      buildPhase = ''
        runHook preBuild
        cp ${binaryTarball} bitcoin-${version}-${platform}.tar.gz
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        tar -xzf ${binaryTarball} -C $out --strip-components=1
        rm -f $out/bin/bitcoin-qt $out/bin/test_bitcoin $out/libexec/bitcoin-gui
        runHook postInstall
      '';

      postFixup = pkgs.lib.optionalString (targetSystem == "powerpc64-linux") ''
        # Create compatibility symlink for PowerPC64
        # Bitcoin binaries expect ld64.so.1 but Nix provides ld64.so.2
        mkdir -p $out/lib
        ln -sf ${targetPkgs.glibc}/lib/ld64.so.2 $out/lib/ld64.so.1
        # Add to RPATH so binaries can find it
        for bin in $out/bin/*; do
          if [[ -f "$bin" && -x "$bin" ]]; then
            patchelf --add-rpath $out/lib "$bin" || true
          fi
        done
      '';

      meta = with pkgs.lib; {
        description = "Bitcoin Core Binaries for ${version} (${platform})";
        homepage = "https://bitcoincore.org/";
        license = licenses.mit;
        platforms = platforms.linux; # Only linux builders pls
      };
    };

  mkBitcoinDockerImage = self: versionConfig: targetSystem: tag: let
    bitcoinCore = self.mkBitcoinCoreForPlatform versionConfig targetSystem;
    targetPkgs = getTargetPkgs targetSystem;
    inherit (versionConfig) version;

    dockerArch =
      {
        "x86_64-linux" = "amd64";
        "aarch64-linux" = "arm64";
        "armv7l-linux" = "arm";
        "powerpc64-linux" = "ppc64le";
        "riscv64-linux" = "riscv64";
      }.${
        targetSystem
      } or (throw "Unsupported platform: ${targetSystem}");
  in
    pkgs.dockerTools.buildImage {
      name = "bitcoin/bitcoin";
      tag = tag;
      architecture = dockerArch;

      copyToRoot = pkgs.buildEnv {
        name = "bitcoin-image-root";
        paths = [
          bitcoinCore
          targetPkgs.busybox
        ];
        pathsToLink = ["/bin" "/share"];
      };

      config = {
        Env = [
          "BITCOIN_VERSION=${version}"
          "PATH=/bin:/usr/bin"
        ];

        ExposedPorts = {
          "8332/tcp" = {};
          "8333/tcp" = {};
          "18332/tcp" = {};
          "18333/tcp" = {};
          "18443/tcp" = {};
          "18444/tcp" = {};
          "38333/tcp" = {};
          "38332/tcp" = {};
        };

        Volumes = {
          "/data" = {};
        };

        WorkingDir = "/data";
        Entrypoint = ["${bitcoinCore}/bin/bitcoind"];
        Cmd = ["-datadir=/data"];
      };

      extraCommands = ''
        mkdir -p data
      '';
    };

  mkPushScript = packages: versionConfig: tag: registry: let
    inherit (versionConfig) version;
    supportedPlatforms = [
      {
        name = "amd64";
        system = "x86_64-linux";
      }
      {
        name = "arm64";
        system = "aarch64-linux";
      }
      {
        name = "arm";
        system = "armv7l-linux";
      }
      {
        name = "ppc64";
        system = "powerpc64-linux";
      }
      {
        name = "riscv64";
        system = "riscv64-linux";
      }
    ];

    # Filter to only platforms that have binaries available
    availablePlatforms = builtins.filter (p: versionConfig.binaries ? ${p.system}) supportedPlatforms;

    packageSuffix = builtins.replaceStrings ["."] ["-"] tag;

    loadCommands =
      pkgs.lib.concatMapStrings (platform: let
        packageName = "bitcoin-${packageSuffix}-${platform.name}";
        dockerArch = platform.name;
      in ''
        echo "Loading ${packageName}..."
        docker load < ${packages.${packageName}}
        docker tag bitcoin/bitcoin:${tag} ${registry}/bitcoin:${tag}-${dockerArch}
        docker push ${registry}/bitcoin:${tag}-${dockerArch}

      '')
      availablePlatforms;

    manifestAmendFlags =
      pkgs.lib.concatMapStrings (
        platform: " --amend ${registry}/bitcoin:${tag}-${platform.name}"
      )
      availablePlatforms;
  in
    pkgs.writeScriptBin "push-bitcoin-${packageSuffix}" ''
      #!/usr/bin/env bash
      set -euo pipefail

      if [ $# -ne 1 ]; then
        echo "Usage: $0 <registry>"
        echo "Example: $0 docker.io/myuser"
        exit 1
      fi

      REGISTRY="$1"

      echo "Pushing Bitcoin Core ${version} (${tag}) to ''${REGISTRY}..."

      # Load and push individual architecture images
      ${loadCommands}

      # Create and push manifest
      echo "Creating manifest for ''${REGISTRY}/bitcoin:${tag}..."
      docker manifest rm ''${REGISTRY}/bitcoin:${tag} || true
      docker manifest create ''${REGISTRY}/bitcoin:${tag}${manifestAmendFlags}
      docker manifest push ''${REGISTRY}/bitcoin:${tag}

      echo "Successfully pushed multi-arch image ''${REGISTRY}/bitcoin:${tag}"
    '';

  # Generate packages for all versions, tags, and platforms
  generatePackages = self: versions: let
    platforms = [
      {
        name = "";
        system = system;
      }
      {
        name = "-amd64";
        system = "x86_64-linux";
      }
      {
        name = "-arm64";
        system = "aarch64-linux";
      }
      {
        name = "-arm";
        system = "armv7l-linux";
      }
      {
        name = "-ppc64";
        system = "powerpc64-linux";
      }
      {
        name = "-riscv64";
        system = "riscv64-linux";
      }
    ];

    versionPackages = pkgs.lib.flatten (
      pkgs.lib.mapAttrsToList (
        versionKey: versionConfig:
          pkgs.lib.flatten (
            map (
              tag:
                map (platform: {
                  name = "bitcoin-${builtins.replaceStrings ["."] ["-"] tag}${platform.name}";
                  value = self.mkBitcoinDockerImage self versionConfig platform.system tag;
                })
                platforms
            )
            versionConfig.tags
          )
      )
      versions
    );

    pushPackages = pkgs.lib.flatten (
      pkgs.lib.mapAttrsToList (
        versionKey: versionConfig:
          map (tag: {
            name = "push-bitcoin-${builtins.replaceStrings ["."] ["-"] tag}";
            value = self.mkPushScript self.packages versionConfig tag "\${REGISTRY}";
          })
          versionConfig.tags
      )
      versions
    );
  in
    pkgs.lib.listToAttrs (versionPackages ++ pushPackages);
}
