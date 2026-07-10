# Combo Rule Registry v1 Test

This pass starts turning elemental/material chemistry into data.

It does **not** try to migrate every hazard script yet. Fire Field, Poison Cloud, and Wind Gust still keep their local hazard-to-hazard behavior for this slice. This PR focuses on the generic `PayloadReceiver -> ReactionResolver` path, where a payload hits a target with tags/statuses.

## Branch

`agent/combo-rule-registry-v1`

## Goal

Create a sparse chemistry registry that behaves like a matrix conceptually:

`Incoming Effect Tags x Target Traits -> Reaction`

But instead of storing a huge mostly-empty table, we store only meaningful reaction rows.

## New files

- `scripts/systems/combo_rule.gd`
- `scripts/systems/combo_rule_registry.gd`
- `data/combo_rules/ignite_oily_target.tres`
- `data/combo_rules/wet_conduction.tres`
- `data/combo_rules/wet_freeze.tres`
- `data/combo_rules/frozen_shatter.tres`

## Updated files

- `scripts/systems/reaction_resolver.gd`

`ReactionResolver` now routes through `ComboRuleRegistry`, but keeps its public method shape:

- `resolve_payload_reactions(target, payload)`
- `target_has_status_or_tag(target, name)`
- `get_debug_matrix_rows()`

## Current rules

| Incoming | Target trait | Reaction | Output |
|---|---|---|---|
| `fire` | `oily` | `ignite_oil` | applies `burning` |
| `lightning` | `wet` | `wet_conduction` | applies `stunned` |
| `ice` | `wet` | `wet_freeze` | applies `frozen` |
| `force` | `frozen` | `shatter` | removes `frozen`, applies reaction damage |

## How to test

1. Pull `agent/combo-rule-registry-v1`.
2. Open the project in Godot.
3. Confirm there are no parser errors from:
   - `combo_rule.gd`
   - `combo_rule_registry.gd`
   - `reaction_resolver.gd`
4. Run the usual dev scene.
5. Spawn enemies / test targets that can receive statuses.
6. Apply or set up these statuses/traits if available in the scene:
   - `wet`
   - `oily`
   - `frozen`
7. Hit them with:
   - Fire for oily ignition.
   - Lightning for wet conduction.
   - Ice for wet freeze.
   - Force for shatter.

## Regression checks

These should still work like before:

- Fire + oily target applies burning.
- Lightning + wet target stuns.
- Ice + wet target freezes.
- Force + frozen target shatters.
- PayloadReceiver debug still shows `rx` reaction names.
- Combat reaction feedback still appears.
- Normal payload damage still applies after reactions.

## Existing hazard combos

These remain in their existing scripts for now:

- Fire Field + Poison Cloud -> Toxic Ignition
- Wind Gust + Poison Cloud -> Cloud Spread
- Wind Gust + Fire Field -> Fanned Flames

That is intentional. This PR creates the registry first, then later passes can migrate hazard-to-hazard reactions into the same data format.

## Design notes

This is a sparse matrix.

Instead of building a giant table like:

```txt
          grass   ice   oil   metal   wet_enemy
fire      burn    melt  ignite heat    steam/burn
slash     cut     -     -      -       -
force     -       break spread clang   push
ice       -       -     -      -       freeze
```

we store only the rows that matter:

```txt
fire + oily -> ignite_oil
lightning + wet -> wet_conduction
ice + wet -> wet_freeze
force + frozen -> shatter
```

Future rules can cover physical materials:

- `slash` + `grass` -> `cut`
- `bludgeon` + `ice` -> `shatter`
- `fire` + `ice` -> `melt`
- `water` + `burning` -> `extinguish`
- `sound` + `brittle` -> `resonate_shatter`
- `lightning` + `metal` -> `conduct`

The matrix is the mental model. The registry is the storage model.
