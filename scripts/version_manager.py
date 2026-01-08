#!/usr/bin/env python3
"""
Bitcoin Core Docker Version Manager

Commands:
    add <VERSION>       Add a new Bitcoin Core version
    deprecate <VERSION> Deprecate an existing version
    list                List active versions

Zero dependencies - uses only Python standard library.
"""

import argparse
import re
import shutil
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

        # Parse: major.minor[.patch][rcN]
        match = re.match(r"^(\d+)\.(\d+)(?:\.(\d+))?(rc(\d+))?$", version_str)
        if not match:
            raise ValueError(f"Invalid version format: {version_str}")

        self.major = int(match.group(1))
        self.minor = int(match.group(2))
        self.patch = int(match.group(3)) if match.group(3) else 0
        self.rc = int(match.group(5)) if match.group(5) else None

    def __str__(self):
        return self.original

    def __repr__(self):
        return f"Version({self.original!r})"

    def __lt__(self, other):
        # Compare major.minor.patch first
        self_tuple = (self.major, self.minor, self.patch)
        other_tuple = (other.major, other.minor, other.patch)
        if self_tuple != other_tuple:
            return self_tuple < other_tuple
        # RC versions are less than release versions
        if self.rc is None and other.rc is None:
            return False
        if self.rc is None:
            return False  # self is release, other is RC
        if other.rc is None:
            return True  # self is RC, other is release
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

    def __gt__(self, other):
        return not self <= other

    def __ge__(self, other):
        return not self < other

    @property
    def is_rc(self):
        return self.rc is not None


class VersionManager:
    """Manages Bitcoin Core Docker versions."""

    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.deprecated_dir = repo_root / "deprecated"
        self.workflow_file = repo_root / ".github" / "workflows" / "build.yml"
        self.readme_file = repo_root / "README.md"

    def get_active_versions(self) -> list[Version]:
        """Return sorted list of active (non-deprecated) versions."""
        versions = []
        for path in self.repo_root.iterdir():
            if not path.is_dir():
                continue
            if path.name.startswith("."):
                continue
            if path.name in ("deprecated", "master", "scripts"):
                continue
            try:
                versions.append(Version(path.name))
            except ValueError:
                continue
        return sorted(versions)

    def get_latest_version(self) -> Version | None:
        """Get the highest non-RC version."""
        versions = [v for v in self.get_active_versions() if not v.is_rc]
        return max(versions) if versions else None

    def get_active_version_for_major(self, major: int) -> Version | None:
        """Get the active version for a given major version."""
        versions = [v for v in self.get_active_versions() if v.major == major]
        return max(versions) if versions else None

    def version_exists(self, version: Version) -> bool:
        """Check if version exists (active or deprecated)."""
        active_path = self.repo_root / version.original
        deprecated_path = self.deprecated_dir / version.original
        return active_path.exists() or deprecated_path.exists()

    def add_version(self, version_str: str, from_version_str: str | None = None):
        """Add a new Bitcoin Core version.

        Args:
            version_str: New version to create (e.g., "29.3")
            from_version_str: Optional source version to copy from. If not specified,
                              uses the active version with the same major, or latest.
        """
        version = Version(version_str)

        # Validate
        if self.version_exists(version):
            print(f"Error: Version {version} already exists", file=sys.stderr)
            sys.exit(1)

        # Determine source version
        if from_version_str:
            source_version = Version(from_version_str)
            # Check active first, then deprecated
            source_dir = self.repo_root / source_version.original
            if not source_dir.exists():
                source_dir = self.deprecated_dir / source_version.original
            if not source_dir.exists():
                print(
                    f"Error: Source version {source_version} not found", file=sys.stderr
                )
                sys.exit(1)
        else:
            # Try to find active version with same major, otherwise use latest
            source_version = self.get_active_version_for_major(version.major)
            if not source_version:
                source_version = self.get_latest_version()
            if not source_version:
                print("Error: No existing version to copy from", file=sys.stderr)
                sys.exit(1)
            source_dir = self.repo_root / source_version.original

        target_dir = self.repo_root / version.original

        # Check if we should auto-deprecate (same major version AND source is active)
        source_is_active = source_dir.parent == self.repo_root
        auto_deprecate = source_version.major == version.major and source_is_active

        print(f"Adding version {version} (copying from {source_version})")
        if auto_deprecate:
            print(f"  Will auto-deprecate {source_version} (same major version)")

        # Copy directory structure
        print(f"  Copying {source_dir} -> {target_dir}")
        shutil.copytree(source_dir, target_dir)

        # Update version in Dockerfiles
        self._update_dockerfile_version(
            target_dir / "Dockerfile", source_version.original, version.original
        )
        self._update_dockerfile_version(
            target_dir / "alpine" / "Dockerfile",
            source_version.original,
            version.original,
        )

        # Update workflow
        print("  Updating .github/workflows/build.yml")
        self._add_version_to_workflow(version.original)

        # Auto-deprecate old version if same major
        if auto_deprecate:
            print(f"  Auto-deprecating {source_version}")
            self._deprecate_version_internal(source_version)

        # Update README
        print("  Updating README.md")
        self._update_readme()

        print(f"Successfully added version {version}")
        if auto_deprecate:
            print(f"  (auto-deprecated {source_version})")
        print("\nNext steps:")
        print("  1. Review changes: git diff")
        print(f"  2. Test build: docker build {target_dir}")
        print(f"  3. Commit: git add -A && git commit -m 'Add v{version}'")

    def _deprecate_version_internal(self, version: Version):
        """Internal method to deprecate a version (no README update, no user prompts)."""
        source_dir = self.repo_root / version.original
        target_dir = self.deprecated_dir / version.original

        # Move to deprecated
        self.deprecated_dir.mkdir(exist_ok=True)
        shutil.move(source_dir, target_dir)

        # Update workflow
        self._remove_version_from_workflow(version.original)

    def deprecate_version(self, version_str: str):
        """Deprecate an existing version."""
        version = Version(version_str)
        source_dir = self.repo_root / version.original
        target_dir = self.deprecated_dir / version.original

        if not source_dir.exists():
            print(
                f"Error: Version {version} not found in active versions",
                file=sys.stderr,
            )
            sys.exit(1)

        if target_dir.exists():
            print(
                f"Error: Version {version} already exists in deprecated/",
                file=sys.stderr,
            )
            sys.exit(1)

        latest = self.get_latest_version()
        if latest and version == latest:
            print(f"Warning: Deprecating the 'latest' version ({version})")
            print("  The next highest version will become 'latest'")

        print(f"Deprecating version {version}")

        # Move to deprecated
        print(f"  Moving {source_dir} -> {target_dir}")
        self._deprecate_version_internal(version)

        # Update README
        print("  Updating README.md")
        self._update_readme()

        print(f"Successfully deprecated version {version}")
        print("\nNext steps:")
        print("  1. Review changes: git diff")
        print(f"  2. Commit: git add -A && git commit -m 'Deprecate v{version}'")

    def list_versions(self):
        """List active versions."""
        versions = self.get_active_versions()
        latest = self.get_latest_version()

        print("Active versions:")
        for v in versions:
            suffix = " (latest)" if latest and v == latest else ""
            suffix += " (rc)" if v.is_rc else ""
            print(f"  {v}{suffix}")

    def _update_dockerfile_version(
        self, dockerfile: Path, old_version: str, new_version: str
    ):
        """Update BITCOIN_VERSION in a Dockerfile."""
        content = dockerfile.read_text()
        # Replace ENV BITCOIN_VERSION=X.Y with new version
        updated = re.sub(
            rf"(ENV BITCOIN_VERSION=){re.escape(old_version)}",
            rf"\g<1>{new_version}",
            content,
        )
        dockerfile.write_text(updated)

    def _add_version_to_workflow(self, version: str):
        """Add version to build.yml paths and replace matrix with just this version."""
        content = self.workflow_file.read_text()

        # Add to paths section
        # Find: paths:\n      - 'X.Y/**'
        # Insert new path at the beginning of the list
        paths_pattern = r"(paths:\n)"
        paths_replacement = rf"\g<1>      - '{version}/**'\n"
        content = re.sub(paths_pattern, paths_replacement, content)

        # Replace entire matrix with just the new version
        # Match: version:\n followed by any number of entries until fail-fast
        matrix_pattern = r"(version:\n)(?:          - '[^']+'\n)+(\s+fail-fast:)"
        matrix_replacement = (
            rf"\g<1>          - '{version}/alpine'\n          - '{version}'\n\g<2>"
        )
        content = re.sub(matrix_pattern, matrix_replacement, content)

        self.workflow_file.write_text(content)

    def _remove_version_from_workflow(self, version: str):
        """Remove version from build.yml paths and matrix using regex."""
        content = self.workflow_file.read_text()

        # Remove from paths
        content = re.sub(rf"      - '{re.escape(version)}/\*\*'\n", "", content)

        # Remove from matrix (both alpine and regular)
        content = re.sub(rf"          - '{re.escape(version)}/alpine'\n", "", content)
        content = re.sub(rf"          - '{re.escape(version)}'\n", "", content)

        self.workflow_file.write_text(content)

    def _update_readme(self):
        """Update README.md tags section based on active versions."""
        content = self.readme_file.read_text()

        versions = self.get_active_versions()
        latest = self.get_latest_version()

        # Build new tags section
        lines = []
        for v in sorted(versions, reverse=True):
            major = v.major
            is_latest = latest and v == latest

            # Debian line
            if v.is_rc:
                tags = f"`{v.original}`"
            elif is_latest:
                tags = f"`{v.original}`, `{major}`, `latest`"
            else:
                tags = f"`{v.original}`, `{major}`"
            dockerfile_link = f"[{v.original}/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/{v.original}/Dockerfile)"
            lines.append(f"- {tags} ({dockerfile_link}) [**multi-platform**]")

            # Alpine line
            if v.is_rc:
                alpine_tags = f"`{v.original}-alpine`"
            elif is_latest:
                alpine_tags = f"`{v.original}-alpine`, `{major}-alpine`, `alpine`"
            else:
                alpine_tags = f"`{v.original}-alpine`, `{major}-alpine`"
            alpine_link = f"[{v.original}/alpine/Dockerfile](https://github.com/willcl-ark/bitcoin-core-docker/blob/master/{v.original}/alpine/Dockerfile)"
            lines.append(f"- {alpine_tags} ({alpine_link})")
            lines.append("")  # Blank line between versions

        new_tags = "\n".join(lines)

        # Replace tags section (between "## Tags" and "### Picking")
        pattern = r"(## Tags\n\n)(.*?)(### Picking the right tag)"
        replacement = rf"\g<1>{new_tags}\n\g<3>"
        updated = re.sub(pattern, replacement, content, flags=re.DOTALL)

        self.readme_file.write_text(updated)


def main():
    parser = argparse.ArgumentParser(
        description="Bitcoin Core Docker Version Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # add command
    add_parser = subparsers.add_parser("add", help="Add a new version")
    add_parser.add_argument("version", help="Version to add (e.g., 29.3, 31.0)")
    add_parser.add_argument(
        "from_version",
        nargs="?",
        help="Source version to copy from (default: same major or latest)",
    )

    # deprecate command
    dep_parser = subparsers.add_parser(
        "deprecate", help="Deprecate an existing version"
    )
    dep_parser.add_argument("version", help="Version to deprecate")

    # list command
    subparsers.add_parser("list", help="List active versions")

    args = parser.parse_args()

    # Find repo root (directory containing .github)
    repo_root = Path(__file__).parent.parent
    if not (repo_root / ".github").exists():
        print("Error: Could not find repository root", file=sys.stderr)
        sys.exit(1)

    manager = VersionManager(repo_root)

    if args.command == "add":
        manager.add_version(args.version, args.from_version)
    elif args.command == "deprecate":
        manager.deprecate_version(args.version)
    elif args.command == "list":
        manager.list_versions()


if __name__ == "__main__":
    main()
