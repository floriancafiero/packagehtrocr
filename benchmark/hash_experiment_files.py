#!/usr/bin/env python3
"""Create a SHA-256 manifest for frozen experiment files.

Usage:
    python benchmark/hash_experiment_files.py \
      benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv \
      benchmark/prompts/cmmhwr_neutral.txt \
      benchmark/prompts/cmmhwr_catmus.txt \
      benchmark/prompts/cmmhwr_diplomatic.txt \
      > benchmark/cmmhwr/EXPERIMENT_SHA256.txt
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "Usage: hash_experiment_files.py <file> [<file> ...]",
            file=sys.stderr,
        )
        return 2

    paths = [Path(arg) for arg in sys.argv[1:]]
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        print(
            "Missing files: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    for path in sorted(paths, key=lambda p: str(p)):
        print(f"{sha256(path)}  {path.as_posix()}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
