#!/usr/bin/env python3
"""Validate the planning capability inventory.

This is intentionally separate from the launchable feature registry. The feature
registry owns permanent scenes and CI execution. The capability inventory owns
planning memory, canonical mechanic ownership, aliases, and resuggestion policy.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INVENTORY_PATH = ROOT / "data" / "features" / "capability_inventory.json"
ALLOWED_LIFECYCLES = {
    "canonical",
    "story_integrated",
    "experimental",
    "superseded",
    "scratch",
}


def fail(message: str) -> None:
    raise SystemExit(f"CAPABILITY_INVENTORY_VALIDATION: FAIL: {message}")


def require_string(row: dict[str, Any], key: str, capability_id: str) -> str:
    value = row.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(f"{capability_id}: {key} must be a non-empty string")
    return value.strip()


def main() -> None:
    if not INVENTORY_PATH.is_file():
        fail(f"missing {INVENTORY_PATH.relative_to(ROOT)}")

    try:
        payload = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON: {exc}")

    if payload.get("schema_version") != 1:
        fail("schema_version must be 1")

    capabilities = payload.get("capabilities")
    if not isinstance(capabilities, list) or not capabilities:
        fail("capabilities must be a non-empty array")

    seen_ids: set[str] = set()
    seen_aliases: dict[str, str] = {}

    for index, raw_row in enumerate(capabilities):
        if not isinstance(raw_row, dict):
            fail(f"row {index} must be an object")
        capability_id = require_string(raw_row, "id", f"row {index}")
        if capability_id in seen_ids:
            fail(f"duplicate capability id: {capability_id}")
        seen_ids.add(capability_id)

        require_string(raw_row, "display_name", capability_id)

        lifecycle = raw_row.get("lifecycle")
        if not isinstance(lifecycle, list) or not lifecycle:
            fail(f"{capability_id}: lifecycle must be a non-empty array")
        lifecycle_values = {str(value) for value in lifecycle}
        invalid_lifecycle = lifecycle_values - ALLOWED_LIFECYCLES
        if invalid_lifecycle:
            fail(
                f"{capability_id}: invalid lifecycle values "
                + ", ".join(sorted(invalid_lifecycle))
            )

        implemented = raw_row.get("implemented")
        if not isinstance(implemented, bool):
            fail(f"{capability_id}: implemented must be boolean")

        do_not_resuggest = raw_row.get("do_not_resuggest")
        if not isinstance(do_not_resuggest, bool):
            fail(f"{capability_id}: do_not_resuggest must be boolean")
        if implemented and not do_not_resuggest:
            fail(
                f"{capability_id}: implemented capabilities must set "
                "do_not_resuggest=true; propose integration or expansion instead"
            )

        owners = raw_row.get("owner_files")
        if not isinstance(owners, list) or not owners:
            fail(f"{capability_id}: owner_files must be a non-empty array")
        for owner in owners:
            if not isinstance(owner, str) or not owner.strip():
                fail(f"{capability_id}: owner_files entries must be non-empty strings")

        canonical_scene = raw_row.get("canonical_scene")
        if canonical_scene is not None and (
            not isinstance(canonical_scene, str) or not canonical_scene.strip()
        ):
            fail(f"{capability_id}: canonical_scene must be a non-empty string")

        aliases = raw_row.get("aliases")
        if not isinstance(aliases, list) or not aliases:
            fail(f"{capability_id}: aliases must be a non-empty array")
        for alias_raw in aliases:
            if not isinstance(alias_raw, str) or not alias_raw.strip():
                fail(f"{capability_id}: aliases entries must be non-empty strings")
            alias = alias_raw.strip().casefold()
            previous = seen_aliases.get(alias)
            if previous is not None and previous != capability_id:
                fail(
                    f"alias '{alias_raw}' belongs to both {previous} and {capability_id}"
                )
            seen_aliases[alias] = capability_id

    print(
        "CAPABILITY_INVENTORY_VALIDATION: PASS "
        f"({len(capabilities)} capabilities, {len(seen_aliases)} aliases)"
    )


if __name__ == "__main__":
    main()
