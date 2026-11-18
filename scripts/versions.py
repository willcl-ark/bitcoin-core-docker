"""Bitcoin Core version parsing shared by the scripts in this directory."""

import re
from functools import total_ordering

VERSION_RE = re.compile(r"^(\d+)\.(\d+)(?:\.(\d+))?(?:rc(\d+))?$")


@total_ordering
class Version:
    """A version of the form major.minor[.patch][rcN]; RCs sort before their release."""

    def __init__(self, version_str: str):
        match = VERSION_RE.match(version_str)
        if not match:
            raise ValueError(f"Invalid version format: {version_str}")
        major, minor, patch, rc = match.groups()
        self.original = version_str
        self.major = int(major)
        self.minor = int(minor)
        self.patch = int(patch or 0)
        self.rc = int(rc) if rc else None

    def _sort_key(self):
        return (self.major, self.minor, self.patch, not self.is_rc, self.rc or 0)

    def __eq__(self, other):
        return self._sort_key() == other._sort_key()

    def __lt__(self, other):
        return self._sort_key() < other._sort_key()

    def __str__(self):
        return self.original

    def __repr__(self):
        return f"Version({self.original!r})"

    @property
    def is_rc(self):
        return self.rc is not None
