---
applyTo: "**/*.gd,**/*.tscn,**/*.tres,project.godot"
---

# Godot 4.6 instructions

- Use Godot 4.6 and GDScript syntax compatible with the project configuration.
- Follow the existing typed GDScript style. Give local variables and function arguments explicit types when inference could be ambiguous.
- Preserve existing scene ownership, node names, groups, signals, and exported property contracts unless the issue explicitly changes them.
- Prefer reusable scenes, Resources, and components over duplicating behavior in level scripts.
- Reuse existing payloads, receivers, statuses, reaction rules, and actor component stacks.
- Treat `project.godot` changes as cross-cutting. Add inputs or autoloads only when the assigned issue requires them and document the impact.
- Keep prototype debug affordances visible and clearly development-only.
- Do not commit `.godot/`, editor caches, local save files, or generated artifacts unrelated to the task.
- After changes, run the headless import and startup smoke tests and add focused manual playtest steps for behavior that cannot be verified headlessly.
