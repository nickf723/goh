#!/usr/bin/env python3
"""Validate Grace of Humanity's canonical development feature registry."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

DEFAULT_REGISTRY_PATH = Path("data/features/feature_registry.json")
ALLOWED_STATUSES = {
    "vertical_slice",
    "prototype_verified",
    "development_tool",
    "infrastructure",
    "experimental",
    "disabled",
}
ALLOWED_TEMPORARY_STATES = {"none", "runtime_only", "persistent", "mixed"}
REQUIRED_FIELDS = {
    "id",
    "order",
    "display_name",
    "category",
    "version",
    "status",
    "description",
    "scene",
    "validation_scenes",
    "automated_tests",
    "dependencies",
    "controls",
    "manual_test",
    "temporary_state",
    "story_integrated",
    "limitations",
    "launchable",
    "visible_in_launcher",
    "ci_validate",
    "timeout_seconds",
}
FEATURE_ID_PATTERN = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")


def repository_root_from_script() -> Path:
    return Path(__file__).resolve().parents[2]


def resolve_registry_path(repo_root: Path, registry_argument: str | Path) -> Path:
    registry_path = Path(registry_argument)
    if registry_path.is_absolute():
        return registry_path
    return repo_root / registry_path


def resolve_project_path(repo_root: Path, registered_path: str) -> Path:
    normalized = registered_path.strip()
    if normalized.startswith("res://"):
        normalized = normalized[len("res://") :]
    return repo_root / normalized.lstrip("/")


def load_registry(registry_path: Path) -> dict[str, Any]:
    try:
        with registry_path.open("r", encoding="utf-8") as registry_file:
            data = json.load(registry_file)
    except FileNotFoundError as exc:
        raise ValueError(f"Registry file is missing: {registry_path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"Registry JSON error at line {exc.lineno}, column {exc.colno}: {exc.msg}"
        ) from exc

    if not isinstance(data, dict):
        raise ValueError("Registry root must be a JSON object.")
    return data


def validate_string_list(
    feature_id: str,
    field_name: str,
    value: Any,
    errors: list[str],
    *,
    allow_empty: bool,
) -> list[str]:
    if not isinstance(value, list):
        errors.append(f"{feature_id}: {field_name} must be an array.")
        return []

    if not allow_empty and not value:
        errors.append(f"{feature_id}: {field_name} must not be empty.")

    resolved: list[str] = []
    seen: set[str] = set()
    for index, raw_value in enumerate(value):
        if not isinstance(raw_value, str) or not raw_value.strip():
            errors.append(
                f"{feature_id}: {field_name}[{index}] must be a non-empty string."
            )
            continue
        item = raw_value.strip()
        if item in seen:
            errors.append(f"{feature_id}: {field_name} contains duplicate value: {item}")
            continue
        seen.add(item)
        resolved.append(item)
    return resolved


def validate_registered_path(
    repo_root: Path,
    feature_id: str,
    field_name: str,
    registered_path: Any,
    errors: list[str],
    *,
    require_res_path: bool,
    required_suffix: str | None = None,
) -> str | None:
    if not isinstance(registered_path, str) or not registered_path.strip():
        errors.append(f"{feature_id}: {field_name} must be a non-empty path string.")
        return None

    normalized = registered_path.strip()
    if require_res_path and not normalized.startswith("res://"):
        errors.append(f"{feature_id}: {field_name} must use a res:// path: {normalized}")
        return normalized

    if required_suffix and not normalized.endswith(required_suffix):
        errors.append(
            f"{feature_id}: {field_name} must end with {required_suffix}: {normalized}"
        )

    resolved = resolve_project_path(repo_root, normalized)
    if not resolved.is_file():
        errors.append(f"{feature_id}: {field_name} does not exist: {normalized}")
    return normalized


def validate_path_list(
    repo_root: Path,
    feature_id: str,
    field_name: str,
    value: Any,
    errors: list[str],
    *,
    allow_empty: bool,
) -> list[str]:
    paths = validate_string_list(
        feature_id,
        field_name,
        value,
        errors,
        allow_empty=allow_empty,
    )
    for index, path in enumerate(paths):
        validate_registered_path(
            repo_root,
            feature_id,
            f"{field_name}[{index}]",
            path,
            errors,
            require_res_path=True,
            required_suffix=".tscn",
        )
    return paths


def find_dependency_cycle(graph: dict[str, list[str]]) -> list[str]:
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []

    def visit(node: str) -> list[str]:
        if node in visiting:
            cycle_start = stack.index(node)
            return stack[cycle_start:] + [node]
        if node in visited:
            return []

        visiting.add(node)
        stack.append(node)
        for dependency in graph.get(node, []):
            cycle = visit(dependency)
            if cycle:
                return cycle
        stack.pop()
        visiting.remove(node)
        visited.add(node)
        return []

    for feature_id in graph:
        cycle = visit(feature_id)
        if cycle:
            return cycle
    return []


def validate_registry_data(
    registry: dict[str, Any], repo_root: Path
) -> tuple[list[dict[str, Any]], list[str]]:
    errors: list[str] = []

    schema_version = registry.get("schema_version")
    if not isinstance(schema_version, int) or isinstance(schema_version, bool) or schema_version <= 0:
        errors.append("schema_version must be a positive integer.")

    raw_features = registry.get("features")
    if not isinstance(raw_features, list) or not raw_features:
        errors.append("features must be a non-empty array.")
        return [], errors

    features: list[dict[str, Any]] = []
    feature_by_id: dict[str, dict[str, Any]] = {}
    seen_orders: dict[int, str] = {}

    for index, raw_feature in enumerate(raw_features):
        if not isinstance(raw_feature, dict):
            errors.append(f"features[{index}] must be an object.")
            continue

        feature = raw_feature
        features.append(feature)
        feature_id_value = feature.get("id")
        feature_id = (
            feature_id_value.strip()
            if isinstance(feature_id_value, str) and feature_id_value.strip()
            else f"features[{index}]"
        )

        missing_fields = sorted(REQUIRED_FIELDS - set(feature))
        for missing_field in missing_fields:
            errors.append(f"{feature_id}: missing required field: {missing_field}")

        if not isinstance(feature_id_value, str) or not feature_id_value.strip():
            errors.append(f"features[{index}]: id must be a non-empty string.")
        elif not FEATURE_ID_PATTERN.fullmatch(feature_id_value.strip()):
            errors.append(
                f"{feature_id}: id must use lowercase snake_case letters and numbers."
            )
        elif feature_id in feature_by_id:
            errors.append(f"{feature_id}: duplicate feature id.")
        else:
            feature_by_id[feature_id] = feature

        order = feature.get("order")
        if not isinstance(order, int) or isinstance(order, bool) or order < 0:
            errors.append(f"{feature_id}: order must be a non-negative integer.")
        elif order in seen_orders:
            errors.append(
                f"{feature_id}: order {order} duplicates {seen_orders[order]}."
            )
        else:
            seen_orders[order] = feature_id

        for string_field in ("display_name", "category", "version", "description"):
            value = feature.get(string_field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{feature_id}: {string_field} must be a non-empty string.")

        status = feature.get("status")
        if status not in ALLOWED_STATUSES:
            errors.append(f"{feature_id}: unsupported status: {status!r}")

        temporary_state = feature.get("temporary_state")
        if temporary_state not in ALLOWED_TEMPORARY_STATES:
            errors.append(
                f"{feature_id}: unsupported temporary_state: {temporary_state!r}"
            )

        for bool_field in (
            "story_integrated",
            "launchable",
            "visible_in_launcher",
            "ci_validate",
        ):
            if not isinstance(feature.get(bool_field), bool):
                errors.append(f"{feature_id}: {bool_field} must be a boolean.")

        if feature.get("visible_in_launcher") is True and feature.get("launchable") is not True:
            errors.append(f"{feature_id}: visible launcher entries must be launchable.")

        timeout_seconds = feature.get("timeout_seconds")
        if (
            not isinstance(timeout_seconds, int)
            or isinstance(timeout_seconds, bool)
            or timeout_seconds <= 0
        ):
            errors.append(f"{feature_id}: timeout_seconds must be a positive integer.")

        validate_registered_path(
            repo_root,
            feature_id,
            "scene",
            feature.get("scene"),
            errors,
            require_res_path=True,
            required_suffix=".tscn",
        )
        validate_registered_path(
            repo_root,
            feature_id,
            "manual_test",
            feature.get("manual_test"),
            errors,
            require_res_path=False,
            required_suffix=".md",
        )
        validate_path_list(
            repo_root,
            feature_id,
            "validation_scenes",
            feature.get("validation_scenes"),
            errors,
            allow_empty=False,
        )
        validate_path_list(
            repo_root,
            feature_id,
            "automated_tests",
            feature.get("automated_tests"),
            errors,
            allow_empty=True,
        )
        validate_string_list(
            feature_id,
            "dependencies",
            feature.get("dependencies"),
            errors,
            allow_empty=True,
        )
        validate_string_list(
            feature_id,
            "controls",
            feature.get("controls"),
            errors,
            allow_empty=False,
        )
        validate_string_list(
            feature_id,
            "limitations",
            feature.get("limitations"),
            errors,
            allow_empty=False,
        )

    dependency_graph: dict[str, list[str]] = {}
    for feature_id, feature in feature_by_id.items():
        dependencies = feature.get("dependencies", [])
        if not isinstance(dependencies, list):
            continue
        dependency_graph[feature_id] = []
        for dependency in dependencies:
            if not isinstance(dependency, str):
                continue
            if dependency == feature_id:
                errors.append(f"{feature_id}: feature cannot depend on itself.")
                continue
            if dependency not in feature_by_id:
                errors.append(f"{feature_id}: unknown dependency: {dependency}")
                continue
            dependency_graph[feature_id].append(dependency)

    cycle = find_dependency_cycle(dependency_graph)
    if cycle:
        errors.append("dependency cycle: " + " -> ".join(cycle))

    return sorted(features, key=lambda feature: (feature.get("order", 0), feature.get("id", ""))), errors


def validate_registry_file(
    registry_path: Path, repo_root: Path
) -> tuple[dict[str, Any], list[dict[str, Any]], list[str]]:
    try:
        registry = load_registry(registry_path)
    except ValueError as exc:
        return {}, [], [str(exc)]

    features, errors = validate_registry_data(registry, repo_root)
    return registry, features, errors


def print_feature_summary(features: list[dict[str, Any]]) -> None:
    print("Registered feature matrix:")
    for feature in features:
        launch_marker = "launcher" if feature.get("visible_in_launcher") else "hidden"
        test_count = len(feature.get("automated_tests", []))
        print(
            "  - "
            f"{feature.get('id', 'unknown')}: "
            f"{feature.get('status', 'unknown')} | {launch_marker} | "
            f"{test_count} test(s)"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=str(repository_root_from_script()),
        help="Repository root. Defaults to the directory inferred from this script.",
    )
    parser.add_argument(
        "--registry",
        default=str(DEFAULT_REGISTRY_PATH),
        help="Registry path, relative to the repository unless absolute.",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    registry_path = resolve_registry_path(repo_root, args.registry)
    _, features, errors = validate_registry_file(registry_path, repo_root)

    if errors:
        print("FEATURE_REGISTRY_VALIDATION: FAIL", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print_feature_summary(features)
    print(
        "FEATURE_REGISTRY_VALIDATION: PASS "
        f"({len(features)} features, schema and dependency graph healthy)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
