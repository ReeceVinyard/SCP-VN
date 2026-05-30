#!/usr/bin/env python3
"""Validate .tscn parent paths and flag direct-child $Node refs in scripts."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def validate_tscn(path: Path) -> list[str]:
    text = path.read_text()
    all_paths: list[tuple[str, str, str]] = []
    for m in re.finditer(r'\[node name="([^"]+)"[^\]]*parent="([^"]+)"', text):
        name, parent = m.group(1), m.group(2)
        full = name if parent == "." else f"{parent}/{name}"
        all_paths.append((full, parent, name))
    path_set = {p[0] for p in all_paths}
    errors = []
    for full, parent, name in all_paths:
        if parent != "." and parent not in path_set:
            errors.append(f"{path}: {name} has missing parent {parent!r}")
    return errors


def validate_dollar_refs(path: Path) -> list[str]:
    text = path.read_text()
    errors = []
    for m in re.finditer(r"@onready\s+var\s+\w+[^=]*=\s*\$([A-Za-z_][A-Za-z0-9_]*)", text):
        errors.append(
            f"{path}: @onready uses ${m.group(1)} — prefer %UniqueName after CanvasLayer moves"
        )
    return errors


def main() -> int:
    errors: list[str] = []
    for tscn in sorted(ROOT.rglob("*.tscn")):
        if ".godot" in tscn.parts:
            continue
        errors.extend(validate_tscn(tscn))
    for gd in sorted((ROOT / "scripts").rglob("*.gd")):
        errors.extend(validate_dollar_refs(gd))
    if errors:
        for e in errors:
            print(e, file=sys.stderr)
        print(f"\n{len(errors)} issue(s)", file=sys.stderr)
        return 1
    print("All scene parent paths and @onready refs OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
