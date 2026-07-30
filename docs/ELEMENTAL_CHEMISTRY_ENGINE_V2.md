# Elemental Chemistry Engine v2

## Purpose

The chemistry engine turns spell, weapon, hazard, and material metadata into deterministic world reactions.

The core order is:

1. Capture the target's **pre-impact** states and tags.
2. Read the incoming payload's element, hit type, status, and tags.
3. Find every matching reaction rule.
4. Resolve matches by priority and exclusive group.
5. Apply reaction outputs.
6. Apply the incoming direct status only when no winning rule consumed it.
7. Apply material components and the primary hit.

This prevents an impact from applying a setup state and immediately claiming that state as its own prerequisite.

## Runtime flow

```text
PayloadReceiver
  -> ReactionResolver
    -> ElementalReactionEngine
      -> ReactionRuleCatalog
      -> ReactionTransaction
      -> ReactionOutputExecutor
  -> optional direct status
  -> thermal / combustion / electrical / structural components
  -> primary HitReceiver
```

## Core files

- `scripts/systems/reaction_state_policy.gd`
  - normalizes aliases such as `chilled -> chill`
  - owns state-to-element identity
  - owns status incompatibilities
  - captures target state snapshots

- `scripts/systems/reaction_transaction.gd`
  - assigns a transaction and chain ID
  - records pre-impact state
  - tracks triggered and suppressed rules
  - enforces per-target trigger limits and reaction depth
  - claims exclusive resolution groups

- `scripts/systems/reaction_rule_catalog.gd`
  - combines legacy and v2 rules
  - sorts by priority, then rule ID
  - validates duplicate IDs and malformed rules

- `scripts/systems/elemental_reaction_engine.gd`
  - matches rules against the immutable snapshot
  - resolves priority and exclusivity
  - returns a structured reaction batch

- `scripts/systems/reaction_output_executor.gd`
  - removes and applies statuses
  - invokes target hooks
  - produces lineage-aware reaction damage
  - delegates radial outputs to the shared burst resolver

- `scripts/systems/combo_rule.gd`
  - data contract for authored reactions

## Rule requirements

A rule may require:

- every `incoming_tags` value
- any `incoming_any_tags` value
- every `target_tags` value
- any `target_any_tags` value
- every `target_statuses` value
- any `target_any_statuses` value
- absence of every `required_absent_statuses` value

Payload `element` and `hit_type` count as incoming tags.

For actor targets, pre-existing statuses also count as target tags for backward compatibility. Hazard tags come from `get_hazard_tags()`.

## Conflict resolution

Rules resolve in descending `priority`. Ties resolve alphabetically by `rule_id`.

`exclusive_group` allows only one winning rule in a conceptual lane. Current examples:

- `temperature_resolution`
- `cold_resolution`
- `electrical_resolution`
- `visibility_resolution`

`stop_after_match` prevents all lower-priority rules after a rule resolves.

`consume_incoming_status` prevents the payload's direct status from applying after the reaction. Examples:

- Fire + Frozen becomes Steam, not Steam plus Burning.
- Ice + Wet becomes Frozen, not Frozen plus Chill.
- Water + Burning becomes Steam, not Steam plus Wet.

## Reaction lineage

`DamagePayload` carries runtime-only lineage:

- `reaction_chain_id`
- `reaction_depth`
- `reaction_history`
- `reaction_source_rule`
- `suppress_reactions`

Reaction output damage inherits the original chain. Outputs do not trigger more chemistry unless `output_triggers_reactions` is explicitly enabled on the rule.

Rules can reject reaction-generated payloads with `allow_reaction_payloads = false`.

The default maximum depth is four. A rule may choose a smaller `maximum_reaction_depth`.

## Existing rules preserved

- Fire + Oily -> Ignite
- Lightning + Wet -> Wet Conduction
- Ice + Wet -> Freeze
- Heavy impact + Frozen -> Shatter
- Fire + Frozen -> Steam Burst
- Fire + toxic hazard -> Toxic Ignition
- Air + cloud hazard -> Cloud Spread
- Air + flame hazard -> Fanned Flames

## New v2 rules

### Quench

```text
Water + Burning -> Steamed
```

Removes Burning and consumes incoming Wet.

### Deep Freeze

```text
Ice + Chill -> Frozen
```

Creates a two-step cold control path and consumes incoming Chill.

### Resonant Reveal

```text
Sound + Obscured -> Revealed
```

Removes Obscured and creates a shared detection state.

### Conductive Overload

```text
Lightning + Conductive -> Stunned + small electrical pulse
```

Consumes Conductive and creates a compact nearby electrification burst.

## Authoring checklist

Before adding a rule:

1. Give it a unique `rule_id` and stable `reaction_id`.
2. Require at least one incoming tag and one target state/tag.
3. Decide whether the incoming direct status should survive.
4. Choose an exclusive group when another rule could compete for the same conceptual result.
5. Leave `output_triggers_reactions` false unless the chain is intentional and tested.
6. Keep feedback, color, radius, and duration in the rule resource.
7. Add the resource to `ReactionRuleCatalog`.
8. Extend `elemental_chemistry_engine_smoke_test.gd`.

## Test

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/elemental_chemistry_engine_smoke_test.tscn
```

Expected:

```text
ELEMENTAL_CHEMISTRY_ENGINE_SMOKE_TEST: PASS
```

The regression covers catalog validation, priority ordering, setup isolation, legacy Wet Conduction, Quench, Deep Freeze, Resonant Reveal, Conductive Overload, transaction snapshots, direct-status consumption, lineage IDs, and reaction-depth suppression.
