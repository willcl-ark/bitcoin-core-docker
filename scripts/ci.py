#!/usr/bin/env python3
"""
CI helper script for bitcoin-core-docker builds.

Commands:
    matrix <--ref REF>       Output build matrix as JSON for GitHub Actions
    tags <--version V>       Output Docker tags for a version
    should-push <--ref REF>  Check if images should be pushed (true/false)
"""

import argparse
import json
import re
import sys
from pathlib import Path


class Version:
    """Parsed version with comparison support."""

    def __init__(self, version_str: str):
        self.original = version_str
        self.major = 0
        self.minor = 0
        self.patch = 0
        self.rc = None

        match = re.match(r"^(\d+)\.(\d+)(?:\.(\d+))?(rc(\d+))?$", version_str)
        if not match:
            raise ValueError(f"Invalid version format: {version_str}")

        self.major = int(match.group(1))
        self.minor = int(match.group(2))
        self.patch = int(match.group(3)) if match.group(3) else 0
        self.rc = int(match.group(5)) if match.group(5) else None

    def __str__(self):
        return self.original

    def __lt__(self, other):
        self_tuple = (self.major, self.minor, self.patch)
        other_tuple = (other.major, other.minor, other.patch)
        if self_tuple != other_tuple:
            return self_tuple < other_tuple
        if self.rc is None and other.rc is None:
            return False
        if self.rc is None:
            return False
        if other.rc is None:
            return True
        return self.rc < other.rc

    def __eq__(self, other):
        return (
            self.major == other.major
            and self.minor == other.minor
            and self.patch == other.patch
            and self.rc == other.rc
        )

    def __le__(self, other):
        return self < other or self == other

    def __ge__(self, other):
        return not self < other

    @property
    def is_rc(self):
        return self.rc is not None


def get_repo_root() -> Path:
    """Find repository root (directory containing .github)."""
    repo_root = Path(__file__).parent.parent
    if not (repo_root / ".github").exists():
        print("Error: Could not find repository root", file=sys.stderr)
        sys.exit(1)
    return repo_root


def discover_versions(repo_root: Path) -> list[str]:
    """Find all top-level version directories (excluding deprecated, master, scripts)."""
    exclude = {"deprecated", "master", "scripts", ".github"}
    versions = []
    for path in repo_root.iterdir():
        if not path.is_dir():
            continue
        if path.name.startswith("."):
            continue
        if path.name in exclude:
            continue
        if (path / "Dockerfile").exists():
            try:
                Version(path.name)
                versions.append(path.name)
            except ValueError:
                continue
    return versions


def discover_all_top_level(repo_root: Path) -> list[str]:
    """Find all top-level directories with Dockerfiles (including master)."""
    exclude = {"deprecated", "scripts", ".github"}
    dirs = []
    for path in repo_root.iterdir():
        if not path.is_dir():
            continue
        if path.name.startswith("."):
            continue
        if path.name in exclude:
            continue
        if (path / "Dockerfile").exists():
            dirs.append(path.name)
    return dirs


def get_latest_version(repo_root: Path) -> Version | None:
    """Get the highest non-RC version."""
    versions = []
    for v_str in discover_versions(repo_root):
        try:
            v = Version(v_str)
            if not v.is_rc:
                versions.append(v)
        except ValueError:
            continue
    return max(versions) if versions else None


def get_matrix(github_ref: str, repo_root: Path, version: str | None = None) -> dict:
    """Generate build matrix based on GitHub ref or explicit version."""
    if version:
        version_dir = repo_root / version
        if not version_dir.is_dir():
            print(f"Error: Directory '{version}' does not exist", file=sys.stderr)
            sys.exit(1)
        dirs = [version]
    elif github_ref.startswith("refs/tags/v"):
        tag_version = github_ref.removeprefix("refs/tags/v")
        version_dir = repo_root / tag_version
        if not version_dir.is_dir():
            print(
                f"Error: Directory '{tag_version}' does not exist for tag",
                file=sys.stderr,
            )
            sys.exit(1)
        dirs = [tag_version]
    else:
        dirs = discover_all_top_level(repo_root)

    include = []
    for d in sorted(dirs):
        include.append({"version": d, "variant": "debian"})
        alpine_dir = repo_root / d / "alpine"
        if alpine_dir.is_dir() and (alpine_dir / "Dockerfile").exists():
            include.append({"version": d, "variant": "alpine"})

    return {"include": include}


def generate_tags(version_str: str, alpine: bool, repo_root: Path) -> list[str]:
    """Generate Docker tags for a version.

    Preserves the tag logic from the original build.yml.
    """
    repo = "bitcoin/bitcoin"
    tags = []

    if version_str == "master":
        if alpine:
            tags.append(f"{repo}:master-alpine")
        else:
            tags.append(f"{repo}:master")
        return tags

    try:
        v = Version(version_str)
    except ValueError:
        if alpine:
            return [f"{repo}:{version_str}-alpine"]
        return [f"{repo}:{version_str}"]

    major, minor, patch = v.major, v.minor, v.patch
    rc = v.rc
    is_rc = v.is_rc

    latest = get_latest_version(repo_root)

    if not alpine:
        if is_rc:
            if patch != 0:
                tags.append(f"{repo}:{major}.{minor}.{patch}rc{rc}")
            else:
                tags.append(f"{repo}:{major}.{minor}rc{rc}")
        elif patch != 0:
            tags.append(f"{repo}:{major}.{minor}.{patch}")
            tags.append(f"{repo}:{major}")
        else:
            tags.append(f"{repo}:{major}.{minor}")
            tags.append(f"{repo}:{major}")
    else:
        if is_rc:
            if patch != 0:
                tags.append(f"{repo}:{major}.{minor}.{patch}rc{rc}-alpine")
            else:
                tags.append(f"{repo}:{major}.{minor}rc{rc}-alpine")
        elif patch != 0:
            tags.append(f"{repo}:{major}.{minor}.{patch}-alpine")
            tags.append(f"{repo}:{major}-alpine")
        else:
            tags.append(f"{repo}:{major}.{minor}-alpine")
            tags.append(f"{repo}:{major}-alpine")

    if not is_rc and latest and v >= latest:
        if not alpine:
            if f"{repo}:latest" not in tags:
                tags.append(f"{repo}:latest")
            if f"{repo}:{major}" not in tags:
                tags.append(f"{repo}:{major}")
        else:
            if f"{repo}:alpine" not in tags:
                tags.append(f"{repo}:alpine")
            if f"{repo}:{major}-alpine" not in tags:
                tags.append(f"{repo}:{major}-alpine")

    return tags


def should_push(github_ref: str, version: str | None = None) -> bool:
    """Determine if images should be pushed."""
    if version:
        return version != "master"
    if not github_ref.startswith("refs/tags/v"):
        return False
    tag_version = github_ref.removeprefix("refs/tags/v")
    return tag_version != "master"


def cmd_matrix(args):
    """Handle 'matrix' command."""
    repo_root = get_repo_root()
    matrix = get_matrix(args.ref, repo_root, getattr(args, "version", None))
    print(json.dumps(matrix, separators=(",", ":")))


def cmd_tags(args):
    """Handle 'tags' command."""
    repo_root = get_repo_root()
    tags = generate_tags(args.version, args.alpine, repo_root)
    print(" ".join(tags))


def cmd_should_push(args):
    """Handle 'should-push' command."""
    result = should_push(args.ref, getattr(args, "version", None))
    print("true" if result else "false")


def main():
    parser = argparse.ArgumentParser(
        description="CI helper for bitcoin-core-docker builds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    matrix_parser = subparsers.add_parser("matrix", help="Output build matrix as JSON")
    matrix_parser.add_argument(
        "--ref",
        required=True,
        help="GitHub ref (e.g., refs/tags/v30.2, refs/heads/master)",
    )
    matrix_parser.add_argument(
        "--version",
        help="Override: build only this version (e.g., 30.2)",
    )

    tags_parser = subparsers.add_parser("tags", help="Output Docker tags for a version")
    tags_parser.add_argument(
        "--version", required=True, help="Version (e.g., 30.2, master)"
    )
    tags_parser.add_argument(
        "--alpine", action="store_true", help="Generate alpine tags"
    )

    push_parser = subparsers.add_parser(
        "should-push", help="Check if should push images"
    )
    push_parser.add_argument(
        "--ref",
        required=True,
        help="GitHub ref (e.g., refs/tags/v30.2, refs/heads/master)",
    )
    push_parser.add_argument(
        "--version",
        help="Override: if set, will push this version (e.g., 30.2)",
    )

    args = parser.parse_args()

    if args.command == "matrix":
        cmd_matrix(args)
    elif args.command == "tags":
        cmd_tags(args)
    elif args.command == "should-push":
        cmd_should_push(args)


if __name__ == "__main__":
    main()
