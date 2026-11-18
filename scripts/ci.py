#!/usr/bin/env python3
"""
CI helper script for bitcoin-core-docker builds.

Commands:
    matrix                   Output build matrix as JSON for GitHub Actions
    tags <--version V>       Output Docker tags for a version
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

from versions import Version

REPO = "bitcoin/bitcoin"
REPO_ROOT = Path(__file__).resolve().parent.parent


def discover_versions() -> list[Version]:
    """Top-level version directories containing a Dockerfile."""
    versions = []
    for path in REPO_ROOT.iterdir():
        if not (path / "Dockerfile").exists():
            continue
        try:
            versions.append(Version(path.name))
        except ValueError:
            continue
    return versions


def get_latest_version() -> Version | None:
    """Get the highest non-RC version."""
    releases = [v for v in discover_versions() if not v.is_rc]
    return max(releases, default=None)


def changed_top_level_dirs(base: str) -> set[str]:
    """Top-level directory names with changes between BASE and HEAD."""
    output = subprocess.run(
        ["git", "diff", "--name-only", base, "HEAD"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return {line.split("/", 1)[0] for line in output.splitlines() if "/" in line}


def get_matrix(version: str | None, base: str | None) -> dict:
    """Generate build matrix for an explicit version, changes since BASE, or all."""
    active = [v.original for v in discover_versions()]
    if version:
        if version not in active:
            print(f"Error: '{version}' is not an active version", file=sys.stderr)
            sys.exit(1)
        dirs = [version]
    elif base:
        changed = changed_top_level_dirs(base)
        dirs = [d for d in active if d in changed]
    else:
        dirs = active

    include = []
    for d in sorted(dirs):
        include.append({"version": d, "variant": "debian"})
        if (REPO_ROOT / d / "alpine" / "Dockerfile").exists():
            include.append({"version": d, "variant": "alpine"})

    return {"include": include}


def generate_tags(version_str: str, alpine: bool) -> list[str]:
    """Version tag, plus major and latest/alpine tags for releases."""
    version = Version(version_str)
    suffix = "-alpine" if alpine else ""
    tags = [f"{version}{suffix}"]
    if not version.is_rc:
        tags.append(f"{version.major}{suffix}")
        latest = get_latest_version()
        if latest and version >= latest:
            tags.append("alpine" if alpine else "latest")
    return [f"{REPO}:{tag}" for tag in tags]


def cmd_matrix(args):
    """Handle 'matrix' command."""
    matrix = get_matrix(args.version, args.base)
    print(json.dumps(matrix, separators=(",", ":")))


def cmd_tags(args):
    """Handle 'tags' command."""
    tags = generate_tags(args.version, args.alpine)
    print(" ".join(tags))


def main():
    parser = argparse.ArgumentParser(
        description="CI helper for bitcoin-core-docker builds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    matrix_parser = subparsers.add_parser("matrix", help="Output build matrix as JSON")
    matrix_group = matrix_parser.add_mutually_exclusive_group()
    matrix_group.add_argument(
        "--version",
        help="Build only this version (e.g., 30.2)",
    )
    matrix_group.add_argument(
        "--base",
        help="Build only versions changed between this commit and HEAD",
    )

    tags_parser = subparsers.add_parser("tags", help="Output Docker tags for a version")
    tags_parser.add_argument("--version", required=True, help="Version (e.g., 30.2)")
    tags_parser.add_argument(
        "--alpine", action="store_true", help="Generate alpine tags"
    )

    args = parser.parse_args()

    if args.command == "matrix":
        cmd_matrix(args)
    elif args.command == "tags":
        cmd_tags(args)


if __name__ == "__main__":
    main()
