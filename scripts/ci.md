# CI Build System

The CI is controlled by `scripts/ci.py` and `.github/workflows/build.yml`.

## Triggers

| Trigger | What's Built | Push to Docker Hub? |
|---------|--------------|---------------------|
| PR to master | Versions changed by the PR | No |
| Push to master | Versions changed by the push | Yes |
| Manual (no version) | All versions + alpine variants | No |
| Manual (version=`30.2`) | Specified version only | Yes |

After a successful push to master, CI creates a `v<version>` git tag for each
pushed version that does not already have one.

## Release process

1. Open a PR with `just add <version>` (or `just deprecate <version>`).
2. Merge it once CI passes. CI pushes the changed versions to Docker Hub and tags them.

### Point releases

`.github/workflows/new-releases.yml` does step 1 daily for new point releases
of active majors on bitcoincore.org. It opens one PR per version, from
`release/<version>`, and never merges.

It skips a version if that branch exists or an open PR already adds it, so close
a PR without deleting its branch to stop the version being proposed again. If a
run pushes a branch but fails to open the PR, delete the branch to retry.

New majors, and majors with an active RC, must be added by hand.

## Versions

"All versions" means all top-level directories containing a `Dockerfile`
(e.g. `30.4`, `31.2`, `32.1`), plus their `alpine/` variants. See
`just list` for the current set.

`deprecated/` is always excluded, and `master/` is built only by the
nightly workflows.

## Manual Workflow Dispatch

To rebuild and push an existing version (e.g., after updating a Dockerfile):

1. Go to **Actions** → **build** workflow
2. Click **Run workflow**
3. Enter the version (e.g., `30.2`)
4. Click **Run workflow**

Leave the version field empty to build all versions without pushing.

## Testing Locally

```bash
# See what would be built for changes since a commit (as in a PR/push to master)
python scripts/ci.py matrix --base origin/master

# See what would be built for manual dispatch without/with version
python scripts/ci.py matrix
python scripts/ci.py matrix --version 30.2

# See Docker tags for a version
python scripts/ci.py tags --version 30.2
python scripts/ci.py tags --version 30.2 --alpine
```

## Docker Tags

Tags are generated based on version number:

| Version | Variant | Docker Tags |
|---------|---------|-------------|
| 30.2 (latest) | debian | `bitcoin/bitcoin:30.2`, `:30`, `:latest` |
| 30.2 (latest) | alpine | `bitcoin/bitcoin:30.2-alpine`, `:30-alpine`, `:alpine` |
| 29.2 | debian | `bitcoin/bitcoin:29.2`, `:29` |
| 29.2 | alpine | `bitcoin/bitcoin:29.2-alpine`, `:29-alpine` |
| 31.0rc1 | debian | `bitcoin/bitcoin:31.0rc1` |
| 31.0rc1 | alpine | `bitcoin/bitcoin:31.0rc1-alpine` |

The highest non-RC version automatically gets the `latest` and `alpine` tags.
Release candidates only get their exact version tag.

## Platform Support

| Version | Variant | Platforms |
|---------|---------|-----------|
| Releases | debian | `linux/amd64`, `linux/arm64`, `linux/arm/v7` |
| Releases | alpine | `linux/amd64` |
| master | nix | `linux/amd64`, `linux/arm64` |
| master | alpine | `linux/amd64`, `linux/arm64` |

## Nightly Builds

The `master` directory is built by separate nightly workflows, from Bitcoin
Core's master branch:
- `.github/workflows/nix-master.yml` - Nix-built image, pushed as `bitcoin/bitcoin:master`
- `.github/workflows/alpine-master.yml` - Alpine image, pushed as `bitcoin/bitcoin:master-alpine`

They push to Docker Hub only on the daily schedule. Pushes that change their
files under `master/` trigger a test build without pushing.
