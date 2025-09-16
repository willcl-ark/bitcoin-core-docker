# Adding a New Bitcoin Core Version

## Overview

1. **Copy existing version directory**
1. **Update version configuration**
1. **Download official SHA256SUMS file**
1. **Update flake dependencies**
1. **Add to root flake**
1. **Test and validate**

## Step-by-Step

### 1. Copy Previous Version Directory

```bash
# Copy the most recent version directory
cp -r 29.1 30.1

# Or for release candidates:
cp -r 30.0rc1 30.1rc1
```

### 2. Update Version Configuration

Edit the new `30.1/flake.nix`:

```bash
cd 30.1
$EDITOR flake.nix
```

Update the version-specific information:

- Change `description` to match new version
- Update `version` field in the versions object
- Update `urlPath` for the new version's download URL
- Update `tags` array (typically `["30.1"]` or add additional tags)

**Example changes:**

```nix
# Change description
description = "Bitcoin Core 30.1 Docker images";

# Update version configuration
versions = {
  "30.1" = shasumsLib.shasumsToVersionConfig {
    version = "30.1";
    urlPath = "bitcoin-core-30.1/";
    tags = ["30.1"];
    shasumsPath = ./SHA256SUMS;
  };
};

# Update default package tag
default = common.mkBitcoinDockerImage self' versions."30.1" system "30.1";
```

### 3. Download Official SHA256SUMS File

Download the official SHA256SUMS file from bitcoincore.org and place it in the version directory:

```bash
# Download the official SHA256SUMS file for the new version
cd 30.1
curl -o SHA256SUMS https://bitcoincore.org/bin/bitcoin-core-30.1/SHA256SUMS

# Or for release candidates:
curl -o SHA256SUMS https://bitcoincore.org/bin/bitcoin-core-30.1/test.rc1/SHA256SUMS
```

The flake will automatically parse this file and extract the required binary hashes for all supported Linux architectures.

### 4. Update Flake Dependencies

Update the version-specific flake.lock to use current nixpkgs:

```bash
cd 30.1
nix flake update
```

**Optional:** Pin to a specific nixpkgs commit for reproducibility:

```bash
# Pin to a specific commit
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/abc123...
```

### 5. Add to Root Flake

Edit the root `flake.nix` to include the new version:

```bash
cd ..  # Back to project root
$EDITOR flake.nix
```

Add the new input:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  flake-utils.url = "github:numtide/flake-utils";
  
  bitcoin-29-1.url = "path:./29.1";
  bitcoin-30-0rc1.url = "path:./30.0rc1";
  bitcoin-30-1.url = "path:./30.1";  # Add this line
};
```

Add to outputs function parameters:

```nix
outputs = {
  self,
  nixpkgs,
  flake-utils,
  bitcoin-29-1,
  bitcoin-30-0rc1,
  bitcoin-30-1,  # Add this line
}:
```

Add to versionFlakes list:

```nix
versionFlakes = [
  bitcoin-29-1
  bitcoin-30-0rc1
  bitcoin-30-1  # Add this line
];
```

**Optional:** Update the default package:

```nix
default = bitcoin-30-1.packages.${system}.default;  # Point to latest version
```

### 6. Update Root Flake Lock

```bash
# Update root flake.lock to include new version input
nix flake lock
```

### 7. Test and Validate

```bash
# Check flake syntax
nix flake check

# List available packages (should show new version)
just list

# Test building a specific architecture
just build 30.1 amd64

# Test that all architectures build
just build-all 30.1
```

## Example: Adding Bitcoin Core 30.1

```bash
# 1. Copy directory
cp -r 29.1 30.1

# 2. Download official SHA256SUMS
cd 30.1
curl -o SHA256SUMS https://bitcoincore.org/bin/bitcoin-core-30.1/SHA256SUMS

# 3. Edit version flake
$EDITOR flake.nix  # Update version, urlPath, and tags

# 4. Update dependencies
nix flake update

# 5. Add to root flake
cd ..
$EDITOR flake.nix  # Add bitcoin-30-1 input and to versionFlakes

# 6. Update root lock
nix flake lock

# 7. Test
nix flake check
just build 30.1 amd64
```

## Tips

### For Release Candidates

- Use directory name like `30.1rc1`
- Download SHA256SUMS from the test.rc* directory (e.g., `bitcoin-core-30.1/test.rc1/SHA256SUMS`)
- Set tags to just `["30.1rc1"]` (don't include "latest")

### For Major Versions

- Consider which tags to include (e.g., `["30.1", "30", "latest"]`)
- Update root flake default to point to the new stable version

### Nixpkgs Pinning

- Each version can use a different nixpkgs commit
- Use `nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/COMMIT` to pin
- Useful for ensuring older versions still build with their contemporary dependencies

### Troubleshooting

- If the SHA256SUMS file is not available, the version might not be released yet
- Check bitcoincore.org/bin/ for the exact URL structure and directory name
- Use `nix flake show` to verify packages are correctly exposed
- Run `just build-all VERSION` to test all architectures before pushing
- The flake automatically filters for Linux GNU tarballs and excludes debug versions

