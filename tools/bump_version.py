#!/usr/bin/env python3
"""Increment the app's patch and Android build numbers for a GitHub release."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


PUBSPEC = Path(__file__).resolve().parents[1] / "pubspec.yaml"
VERSION_LINE = re.compile(
    r"(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)(\r?)$"
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the next version without changing pubspec.yaml",
    )
    args = parser.parse_args()

    source = PUBSPEC.read_bytes().decode("utf-8")
    match = VERSION_LINE.search(source)
    if match is None:
        raise SystemExit(
            "Expected pubspec.yaml version in MAJOR.MINOR.PATCH+BUILD format."
        )

    major, minor, patch, build = (int(value) for value in match.groups()[:4])
    version = f"{major}.{minor}.{patch + 1}+{build + 1}"
    if not args.dry_run:
        replacement = f"version: {version}{match.group(5)}"
        updated = source[: match.start()] + replacement + source[match.end() :]
        PUBSPEC.write_bytes(updated.encode("utf-8"))
    print(version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
