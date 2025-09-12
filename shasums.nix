{
  nixpkgs,
  system,
  ...
}: let
  pkgs = nixpkgs.legacyPackages.${system};

  # Helper function to convert hex hash to base64 for Nix
  hexToBase64Hash = hexHash: let
    # Use nix-prefetch-url --to-sri to convert
    sri = pkgs.runCommand "hex-to-sri" {} ''
      echo "sha256-$(echo -n "${hexHash}" | ${pkgs.xxd}/bin/xxd -r -p | ${pkgs.coreutils}/bin/base64 -w 0)" > $out
    '';
  in
    builtins.readFile sri;

  # Helper to extract platform info from SHASUMS format filename
  platformFromFilename = filename:
    if (builtins.match ".*x86_64-linux-gnu\\.tar\\.gz" filename) != null
    then "x86_64-linux-gnu"
    else if (builtins.match ".*aarch64-linux-gnu\\.tar\\.gz" filename) != null
    then "aarch64-linux-gnu"
    else if (builtins.match ".*arm-linux-gnueabihf\\.tar\\.gz" filename) != null
    then "arm-linux-gnueabihf"
    else if (builtins.match ".*powerpc64-linux-gnu\\.tar\\.gz" filename) != null
    then "powerpc64-linux-gnu"
    else if (builtins.match ".*riscv64-linux-gnu\\.tar\\.gz" filename) != null
    then "riscv64-linux-gnu"
    else throw "Unknown platform in filename: ${filename}";

  # Helper to map platform to Nix system
  platformToSystem = platform:
    if platform == "x86_64-linux-gnu"
    then "x86_64-linux"
    else if platform == "aarch64-linux-gnu"
    then "aarch64-linux"
    else if platform == "arm-linux-gnueabihf"
    then "armv7l-linux"
    else if platform == "powerpc64-linux-gnu"
    then "powerpc64-linux"
    else if platform == "riscv64-linux-gnu"
    then "riscv64-linux"
    else throw "Unknown platform: ${platform}";

  # Parse SHA256SUMS file format
  parseShasumsFile = shasumsPath: let
    content = builtins.readFile shasumsPath;
    lines = pkgs.lib.splitString "\n" content;
    nonEmptyLines = builtins.filter (line: line != "") lines;

    # Parse each line: "hash  filename"
    parseEntry = line: let
      parts = pkgs.lib.splitString "  " line;
    in {
      filename = builtins.elemAt parts 1;
      hash = builtins.elemAt parts 0;
    };

    entries = map parseEntry nonEmptyLines;

    # Convert to attrset
    entriesAttrset = builtins.listToAttrs (map (entry: {
        name = entry.filename;
        value = entry.hash;
      })
      entries);
  in
    entriesAttrset;

  # Convert SHASUMS format to version config format
  shasumsToVersionConfig = {
    version,
    urlPath,
    tags,
    shasumsPath,
  }: let
    shasums = parseShasumsFile shasumsPath;

    # Filter to only Linux tarballs (not debug, not other platforms)
    linuxTarballs =
      pkgs.lib.filterAttrs (
        filename: hash:
          (builtins.match ".*linux-gnu.*\\.tar\\.gz" filename)
          != null
          && (builtins.match ".*-debug\\.tar\\.gz" filename) == null
      )
      shasums;

    # Convert to binaries format
    binaries =
      pkgs.lib.mapAttrs' (filename: hexHash: let
        platform = platformFromFilename filename;
        nixSystem = platformToSystem platform;
      in {
        name = nixSystem;
        value = {
          inherit platform;
          hash = hexToBase64Hash hexHash;
        };
      })
      linuxTarballs;
  in {
    inherit version urlPath tags binaries;
  };
in {
  inherit hexToBase64Hash platformFromFilename platformToSystem parseShasumsFile shasumsToVersionConfig;
}
