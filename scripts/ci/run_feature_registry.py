#!/usr/bin/env python3
"""Boot every CI-enabled feature scene and run every registered Godot test."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from validate_feature_registry import (
    DEFAULT_REGISTRY_PATH,
    repository_root_from_script,
    resolve_registry_path,
    validate_registry_file,
)


@dataclass(frozen=True)
class ValidationTarget:
    feature_id: str
    kind: str
    path: str
    timeout_seconds: int

    @property
    def label(self) -> str:
        return f"{self.feature_id} [{self.kind}] {self.path}"


def build_targets(features: list[dict]) -> list[ValidationTarget]:
    targets: list[ValidationTarget] = []
    seen: set[tuple[str, str]] = set()

    for feature in features:
        if feature.get("ci_validate") is not True:
            continue

        feature_id = str(feature.get("id", "unknown"))
        timeout_seconds = int(feature.get("timeout_seconds", 5))

        for scene_path in feature.get("validation_scenes", []):
            key = ("scene", str(scene_path))
            if key in seen:
                continue
            seen.add(key)
            targets.append(
                ValidationTarget(
                    feature_id=feature_id,
                    kind="scene",
                    path=str(scene_path),
                    timeout_seconds=timeout_seconds,
                )
            )

        for test_path in feature.get("automated_tests", []):
            key = ("test", str(test_path))
            if key in seen:
                continue
            seen.add(key)
            targets.append(
                ValidationTarget(
                    feature_id=feature_id,
                    kind="test",
                    path=str(test_path),
                    timeout_seconds=max(timeout_seconds, 5),
                )
            )

    return targets


def command_for_target(
    godot_executable: str, repo_root: Path, target: ValidationTarget
) -> list[str]:
    command = [
        godot_executable,
        "--headless",
        "--path",
        str(repo_root),
        target.path,
    ]
    if target.kind == "scene":
        command.extend(["--quit-after", str(target.timeout_seconds)])
    return command


def print_process_output(completed: subprocess.CompletedProcess[str]) -> None:
    if completed.stdout.strip():
        print("--- stdout ---")
        print(completed.stdout.rstrip())
    if completed.stderr.strip():
        print("--- stderr ---", file=sys.stderr)
        print(completed.stderr.rstrip(), file=sys.stderr)


def run_target(
    godot_executable: str,
    repo_root: Path,
    target: ValidationTarget,
) -> tuple[bool, str]:
    command = command_for_target(godot_executable, repo_root, target)
    process_timeout = max(target.timeout_seconds * 6, 30)
    print(f"\n== {target.label} ==")

    try:
        completed = subprocess.run(
            command,
            cwd=repo_root,
            text=True,
            capture_output=True,
            timeout=process_timeout,
            check=False,
        )
    except FileNotFoundError:
        return False, f"Godot executable was not found: {godot_executable}"
    except subprocess.TimeoutExpired as exc:
        if exc.stdout:
            print(exc.stdout)
        if exc.stderr:
            print(exc.stderr, file=sys.stderr)
        return False, f"Timed out after {process_timeout} seconds"

    if completed.returncode != 0:
        print_process_output(completed)
        return False, f"Godot exited with code {completed.returncode}"

    notable_lines = [
        line.strip()
        for line in completed.stdout.splitlines()
        if "PASS" in line or "ERROR" in line or "WARNING" in line
    ]
    if notable_lines:
        for line in notable_lines[-8:]:
            print(f"  {line}")

    return True, "passed"


def print_summary(results: Sequence[tuple[ValidationTarget, bool, str]]) -> None:
    print("\nRegistered feature validation summary:")
    for target, passed, detail in results:
        marker = "PASS" if passed else "FAIL"
        print(f"  [{marker}] {target.label} ({detail})")


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
    parser.add_argument(
        "--godot",
        default="godot",
        help="Godot executable or absolute path.",
    )
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    registry_path = resolve_registry_path(repo_root, args.registry)
    _, features, registry_errors = validate_registry_file(registry_path, repo_root)

    if registry_errors:
        print("FEATURE_REGISTRY_RUNNER: registry validation failed", file=sys.stderr)
        for error in registry_errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    targets = build_targets(features)
    if not targets:
        print("FEATURE_REGISTRY_RUNNER: no validation targets registered", file=sys.stderr)
        return 1

    results: list[tuple[ValidationTarget, bool, str]] = []
    for target in targets:
        passed, detail = run_target(args.godot, repo_root, target)
        results.append((target, passed, detail))

    print_summary(results)
    failure_count = sum(1 for _, passed, _ in results if not passed)
    if failure_count:
        print(
            f"FEATURE_REGISTRY_RUNNER: FAIL ({failure_count}/{len(results)} targets failed)",
            file=sys.stderr,
        )
        return 1

    print(f"FEATURE_REGISTRY_RUNNER: PASS ({len(results)} registered targets)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
