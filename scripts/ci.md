# CI Build System

The CI is controlled by `scripts/ci.py` and `.github/workflows/build.yml`.

## Triggers

| Trigger | What's Built | Push to Docker Hub? |
|---------|--------------|---------------------|
| PR to master | All versions + alpine variants | No |
| Push to master | All versions + alpine variants | No |
| Tag push (`v30.2`) | Tagged version only | Yes |
| Manual (no version) | All versions + alpine variants | No |
| Manual (version=`30.2`) | Specified version only | Yes |

If you push a commit and tag together, the branch build is automatically skipped (the tag build handles it).

## Versions

"All versions" means all top-level directories containing a `Dockerfile`:
- `27.2`, `28.3`, `29.2`, `30.2`, `master`
- Plus their `/alpine` variants

The `deprecated/` directory is always excluded.

## Manual Workflow Dispatch

To rebuild and push an existing version (e.g., after updating a Dockerfile):

1. Go to **Actions** → **build** workflow
2. Click **Run workflow**
3. Enter the version (e.g., `30.2`)
4. Click **Run workflow**

Leave the version field empty to build all versions without pushing.

## Testing Locally

```bash
# See what would be built for a PR/push to master
python scripts/ci.py matrix --ref refs/heads/master

# See what would be built for a tag
python scripts/ci.py matrix --ref refs/tags/v30.2

# See what would be built for manual dispatch with version
python scripts/ci.py matrix --ref refs/heads/master --version 30.2

# Check if images would be pushed
python scripts/ci.py should-push --ref refs/tags/v30.2      # true
python scripts/ci.py should-push --ref refs/heads/master    # false
python scripts/ci.py should-push --ref refs/heads/master --version 30.2  # true

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
| master | debian | `bitcoin/bitcoin:master` |
| master | alpine | `bitcoin/bitcoin:master-alpine` |

The highest non-RC version automatically gets the `latest` and `alpine` tags.

## Platform Support

| Version | Variant | Platforms |
|---------|---------|-----------|
| Releases (27.2, etc.) | debian | `linux/amd64`, `linux/arm64`, `linux/arm/v7` |
| Releases | alpine | `linux/amd64` |
| master | debian | `linux/amd64` |
| master | alpine | `linux/amd64` |

Full multi-arch master builds are handled by the nightly workflows.

## Nightly Builds

The `master` directory has separate nightly workflows:
- `.github/workflows/alpine-master.yml` - Daily alpine build
- `.github/workflows/debian-master.yml` - Daily debian build

These run on a schedule and push to Docker Hub automatically.
