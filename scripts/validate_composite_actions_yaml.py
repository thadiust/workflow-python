#!/usr/bin/env python3
"""PyYAML-parse every .github/actions/**/action.yml|action.yaml (syntax only)."""

from __future__ import annotations

import pathlib
import sys

try:
    import yaml
except ImportError:
    print(
        "PyYAML is required (pre-commit should install additional_dependencies).",
        file=sys.stderr,
    )
    sys.exit(2)


def main() -> int:
    root = pathlib.Path(".github/actions")
    if not root.is_dir():
        return 0
    paths = sorted(
        p
        for p in root.rglob("*")
        if p.is_file() and p.name in ("action.yml", "action.yaml")
    )
    if not paths:
        return 0
    errors = 0
    for path in paths:
        try:
            yaml.safe_load(path.read_text(encoding="utf-8"))
        except (yaml.YAMLError, OSError, UnicodeError) as exc:
            print(f"{path}: {exc}", file=sys.stderr)
            errors += 1
        else:
            print("ok", path)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
