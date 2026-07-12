from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AGENT_DIR = ROOT / ".github" / "agents"
COPILOT_INSTRUCTIONS = ROOT / ".github" / "copilot-instructions.md"
ALLOWED_KEYS = {
    "name",
    "description",
    "target",
    "tools",
    "model",
    "disable-model-invocation",
    "user-invocable",
    "infer",
    "mcp-servers",
    "metadata",
}
TOP_LEVEL_KEY = re.compile(r"^([A-Za-z0-9_-]+):")


def validate_profile(path: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    if not lines or lines[0].strip() != "---":
        return [f"{path.relative_to(ROOT)}: missing opening YAML frontmatter delimiter"]

    try:
        closing_index = next(
            index for index, line in enumerate(lines[1:], start=1) if line.strip() == "---"
        )
    except StopIteration:
        return [f"{path.relative_to(ROOT)}: missing closing YAML frontmatter delimiter"]

    frontmatter = lines[1:closing_index]
    body = "\n".join(lines[closing_index + 1 :]).strip()
    keys: set[str] = set()

    for line in frontmatter:
        if not line or line[0].isspace():
            continue
        match = TOP_LEVEL_KEY.match(line)
        if not match:
            errors.append(
                f"{path.relative_to(ROOT)}: malformed top-level frontmatter line: {line!r}"
            )
            continue
        key = match.group(1)
        keys.add(key)
        if key not in ALLOWED_KEYS:
            errors.append(
                f"{path.relative_to(ROOT)}: unsupported frontmatter key {key!r}"
            )

    if "description" not in keys:
        errors.append(f"{path.relative_to(ROOT)}: description is required")
    if "name" not in keys:
        errors.append(f"{path.relative_to(ROOT)}: name is required by this repository")
    if not body:
        errors.append(f"{path.relative_to(ROOT)}: agent prompt body is empty")

    return errors


def main() -> int:
    errors: list[str] = []

    if not AGENT_DIR.is_dir():
        errors.append(".github/agents directory is missing")
        profiles: list[Path] = []
    else:
        profiles = sorted(AGENT_DIR.glob("*.agent.md"))

    if not profiles:
        errors.append("No .github/agents/*.agent.md profiles were found")

    names: dict[str, Path] = {}
    for profile in profiles:
        errors.extend(validate_profile(profile))
        for line in profile.read_text(encoding="utf-8").splitlines()[1:]:
            if line.strip() == "---":
                break
            if line.startswith("name:"):
                name = line.partition(":")[2].strip().lower()
                if name in names:
                    errors.append(
                        f"Duplicate agent name in {profile.relative_to(ROOT)} and "
                        f"{names[name].relative_to(ROOT)}"
                    )
                names[name] = profile
                break

    if not COPILOT_INSTRUCTIONS.is_file():
        errors.append(".github/copilot-instructions.md is missing")

    if errors:
        print("Agent profile validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Validated {len(profiles)} custom agent profiles.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
