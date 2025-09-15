# Build Bitcoin Core Docker images
[private]
default:
    @just --list

# Build a specific version and architecture
build version arch="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Convert version to package name format (replace dots with hyphens)
    version_pkg=$(echo "{{version}}" | tr '.' '-')

    # Determine package name based on whether arch is specified
    if [ "{{arch}}" = "" ]; then
        package="bitcoin-${version_pkg}"
    else
        case "{{arch}}" in
            amd64|x86_64)
                package="bitcoin-${version_pkg}-amd64"
                ;;
            arm64|aarch64)
                package="bitcoin-${version_pkg}-arm64"
                ;;
            arm|armv7)
                package="bitcoin-${version_pkg}-arm"
                ;;
            ppc64|powerpc64)
                package="bitcoin-${version_pkg}-ppc64"
                ;;
            riscv64)
                package="bitcoin-${version_pkg}-riscv64"
                ;;
            *)
                echo "Error: Unknown architecture '{{arch}}'"
                echo "Supported architectures: amd64, arm64, arm, ppc64, riscv64"
                exit 1
                ;;
        esac
    fi

    echo "Building ${package}..."
    nix build ".#${package}" "$@"

# List all available packages
list:
    @nix flake show --json 2>/dev/null | jq -r '.packages["x86_64-linux"] | keys[]' | grep bitcoin | sort

# Check flake syntax
check:
    nix flake check

# Prefetch hashes for a new version
prefetch version:
    #!/usr/bin/env bash
    set -euo pipefail

    # Detect if this is an RC version
    if [[ "{{version}}" =~ rc[0-9]+$ ]]; then
        # Extract base version and RC number for URL path
        base_version=$(echo "{{version}}" | sed -E 's/rc[0-9]+$//')
        rc_num=$(echo "{{version}}" | sed -E 's/.*rc([0-9]+)$/\1/')
        url_path="bitcoin-core-${base_version}/test.rc${rc_num}/"
    else
        url_path="bitcoin-core-{{version}}/"
    fi

    echo "Fetching hashes for Bitcoin Core {{version}}..."
    echo "URL path: ${url_path}"
    echo ""

    # Array of architectures to fetch
    declare -A archs=(
        ["x86_64-linux"]="x86_64-linux-gnu"
        ["aarch64-linux"]="aarch64-linux-gnu"
        ["armv7l-linux"]="arm-linux-gnueabihf"
        ["powerpc64-linux"]="powerpc64-linux-gnu"
        ["riscv64-linux"]="riscv64-linux-gnu"
    )

    echo "\"{{version}}\" = {"
    echo "  version = \"{{version}}\";"
    echo "  urlPath = \"${url_path}\";"
    echo "  tags = [\"{{version}}\"];"
    echo "  binaries = {"

    for arch in "${!archs[@]}"; do
        platform="${archs[$arch]}"
        url="https://bitcoincore.org/bin/${url_path}bitcoin-{{version}}-${platform}.tar.gz"

        echo "    \"${arch}\" = {"
        echo "      platform = \"${platform}\";"

        # Try to fetch the hash
        if hash=$(nix-prefetch-url "$url" 2>/dev/null); then
            base64_hash=$(nix hash convert --hash-algo sha256 --to base64 "$hash" 2>/dev/null)
            echo "      hash = \"sha256-${base64_hash}\";"
        else
            echo "      hash = \"sha256-FAILED-TO-FETCH\"; # Could not fetch $url"
        fi

        echo "    };"
    done

    echo "  };"
    echo "};"

# Load image into Docker
load version arch="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Build
    just build "{{version}}" "{{arch}}"

    # Convert version to package name format
    version_pkg=$(echo "{{version}}" | tr '.' '-')

    if [ "{{arch}}" = "" ]; then
        package="bitcoin-${version_pkg}"
    else
        case "{{arch}}" in
            amd64|x86_64)
                package="bitcoin-${version_pkg}-amd64"
                ;;
            arm64|aarch64)
                package="bitcoin-${version_pkg}-arm64"
                ;;
            arm|armv7)
                package="bitcoin-${version_pkg}-arm"
                ;;
            ppc64|powerpc64)
                package="bitcoin-${version_pkg}-ppc64"
                ;;
            riscv64)
                package="bitcoin-${version_pkg}-riscv64"
                ;;
            *)
                echo "Error: Unknown architecture '{{arch}}'"
                exit 1
                ;;
        esac
    fi

    # Load into Docker
    result=$(nix build ".#${package}" --no-link --print-out-paths)
    echo "Loading ${package} into Docker..."
    docker load < "${result}"

# Build all architectures for a specific version
build-all version:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Building all architectures for Bitcoin Core {{version}}..."
    for arch in amd64 arm64 arm ppc64 riscv64; do
        echo "Building {{version}} for ${arch}..."
        just build "{{version}}" "${arch}"
    done

    echo "Done"

# Push multi-architecture images with manifest to a registry
push version registry:
    #!/usr/bin/env bash
    set -euo pipefail

    # Convert version to package name format
    version_pkg=$(echo "{{version}}" | tr '.' '-')

    # First ensure all architectures are built
    echo "Building all architectures for {{version}}..."
    just build-all "{{version}}"

    # Build the push script
    push_script="push-bitcoin-${version_pkg}"
    echo "Building push script ${push_script}..."
    nix build ".#${push_script}"

    # Execute the push script
    echo "Executing push to {{registry}}..."
    ./result/bin/${push_script} "{{registry}}"
