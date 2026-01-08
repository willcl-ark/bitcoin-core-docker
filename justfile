[private]
@default:
  just --list

# Add a new Bitcoin Core version. Auto-deprecates as appropriate.
add VERSION FROM="":
    # Auto-deprecates old version if same major (e.g., 29.3 deprecates 29.2)
    # Auto-detects source from same major version, or uses latest
    # Examples:
    #   just release 29.3        # copies from 29.2, deprecates 29.2
    #   just release 31.0        # copies from 30.x (latest), no deprecation
    #   just release 29.3 29.2   # explicit source
    python3 scripts/version_manager.py add {{VERSION}} {{FROM}}

# Deprecate an existing version (moves to deprecated/)
deprecate VERSION:
    python3 scripts/version_manager.py deprecate {{VERSION}}

# List active versions
list:
    python3 scripts/version_manager.py list
