# Spell Capability Manifest v1

## Purpose

The spell capability manifest is a generated view of the authored magic system. It does not replace `AbilityDefinition`, payload resources, targeting profiles, or reaction rules.

It reads those sources and answers four questions:

1. What does each spell claim to do?
2. What does its payload actually carry?
3. Which elemental reactions can it set up or trigger?
4. Which gameplay capabilities are represented within each element?

The manifest is intended for designers, automated validation, future combat AI, generated laboratories, menu presentation, and debugging.

## Sources of truth

### AbilityDefinition

Supplies:

- spell identity
- display name and description
- element
- role and tag metadata
- targeting and delivery language
- costs
- trait profile
- scaling identity

### Action payload

Supplies runtime-facing facts when those properties exist:

- damage and stance damage
- payload element and hit type
- applied statuses
- force
- detection behavior
- payload tags

### SpellTargetingCatalog

Supplies the normalized targeting-preview summary and profile validation.

### ReactionRuleCatalog

Supplies reaction requirements, priority, outputs, and reachability.

## Canonical capability buckets

The manifest derives these broad capabilities:

- `damage`
- `control`
- `movement`
- `setup`
- `payoff`
- `terrain`
- `detection`
- `summon`
- `defense`
- `utility`

These are not equip restrictions. They are searchable design descriptors.

A spell may occupy several buckets. Water Jet is a control and setup spell. Firebolt is damage and payoff. Echolocation is detection and utility.

## Reaction connectivity

Each spell record includes:

- `applies_states`
- `triggers_reactions`
- `sets_up_reactions`

`triggers_reactions` is derived from the incoming requirements of the live reaction rules. The spell's element, payload hit type, payload tags, roles, and authored tags all contribute to its incoming identity.

`sets_up_reactions` is derived from normalized statuses the spell applies or declares. Environmental-only states may legitimately have no spell producer and appear as audit warnings rather than structural failures.

## Coverage matrix

The coverage matrix contains one row for each of the sixteen core elements.

Each row reports:

- authored spell count
- count and spell IDs for every capability bucket
- missing core capabilities among damage, control, movement, setup, payoff, terrain, and detection

A missing capability is a design gap, not a build error. Elements are not expected to be mechanically symmetrical. The matrix exists to make asymmetry deliberate.

## Audit severity

### Structural errors

These fail the smoke test:

- missing effective spell IDs
- duplicate spell IDs
- missing display names
- missing elements
- invalid targeting profiles
- invalid or duplicate reaction rules

### Design warnings

These are reported but do not fail validation:

- display-name fallback IDs
- empty role metadata
- payload and spell element disagreement
- reaction rules with no authored spell trigger
- required reaction states with no authored producer
- element capability gaps

## Interaction recipes

`SpellInteractionSimulator` executes representative recipes through the real laboratory target and `PayloadReceiver` pipeline.

Current recipes:

1. Water Jet -> Wet -> Lightning Spark -> Conduct
2. Water Jet -> Wet -> Ice Lance -> Frozen -> Firebolt -> Steam Burst
3. Frozen -> Force -> Shatter
4. Obscured -> Echolocation -> Resonant Reveal

Each step records:

- active statuses
- reaction summary
- transaction ID and snapshot
- feedback message

Recipes are executable contracts, not merely documentation.

## Commands

Run the structural and interaction regression:

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/spell_capability_manifest_smoke_test.tscn
```

Expected:

```text
SPELL_CAPABILITY_MANIFEST_SMOKE_TEST: PASS
```

Export JSON and Markdown reports:

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . --script res://scripts/tools/export_spell_capability_manifest.gd
```

Default output:

```text
user://spell_reports/spell_manifest.json
user://spell_reports/spell_manifest.md
user://spell_reports/spell_audit.json
```

A custom output directory can be supplied after `--`:

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . --script res://scripts/tools/export_spell_capability_manifest.gd -- --output=res://reports/spells
```

## Future clients

The manifest is designed to support:

- reaction-aware enemy and companion AI
- automatic reaction-lab station generation
- spellbook filters and comparison views
- loadout recommendations
- content completeness dashboards
- generated authoring recipes for new reactions
- release-time validation of the complete spell library
