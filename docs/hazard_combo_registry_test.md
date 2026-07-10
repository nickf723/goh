# Hazard Combo Registry Test

## Goal

Move the current hazard-to-hazard reactions toward the same sparse chemistry registry used by generic payload reactions.

The core model is still:

```text
Incoming Effect Tags x Target Hazard Tags -> Reaction
```

The target hazard still owns the actual gameplay method, so the registry decides **what rule matches**, while the hazard script decides **how its body changes**.

## New data rules

| Incoming payload | Target hazard tags | Reaction | Target method |
|---|---|---|---|
| `air` | `poison`, `cloud` | `cloud_spread` | `spread_cloud` |
| `air` | `fire`, `field` | `fanned_flames` | `flare_field` |
| `fire` | `poison`, `cloud` | `toxic_ignition` | `trigger_toxic_ignition` |

## Files touched

- `scripts/systems/combo_rule.gd`
  - Adds `target_reaction_method`.
  - Adds `target_reaction_pass_source_position`.
- `scripts/systems/combo_rule_registry.gd`
  - Preloads the three hazard rules.
  - Adds `resolve_hazard_reactions()`.
  - Adds hazard tag matching through `get_hazard_tags()`.
- `scripts/actions/wind_gust.gd`
  - Routes stirred hazards through the registry before using the legacy fallback.
- `scripts/actions/fire_field.gd`
  - Routes overlapping hazard reactions through the registry before using the legacy fallback.
- `data/combo_rules/hazard_cloud_spread.tres`
- `data/combo_rules/hazard_fanned_flames.tres`
- `data/combo_rules/hazard_toxic_ignition.tres`

## Test setup

Pull branch:

```text
agent/hazard-combo-registry-v1
```

Open Godot and confirm no parser errors from:

- `combo_rule.gd`
- `combo_rule_registry.gd`
- `wind_gust.gd`
- `fire_field.gd`

## Gameplay checks

### Wind Gust + Poison Cloud

1. Cast Poison Cloud.
2. Cast Wind Gust into the cloud.
3. Expected:
   - `Wind Gust stirs Poison Hazard.`
   - `Cloud Spread! Wind blooms the poison cloud wider.`
   - Dev Vision on Wind Gust should show `last = registry: cloud_spread`.

### Wind Gust + Fire Field

1. Cast Fire Field.
2. Cast Wind Gust into the field.
3. Expected:
   - `Wind Gust stirs Fire Hazard.`
   - `Fanned Flames! Wind fattens the fire field.`
   - Dev Vision on Wind Gust should show `last = registry: fanned_flames`.

### Fire Field + Poison Cloud

1. Cast Poison Cloud.
2. Cast Fire Field overlapping the cloud.
3. Expected:
   - `Toxic Ignition! Poison gas flashes into burning venom.`
   - Poison Cloud should shrink to a short ignited lifetime.
   - Targets inside the cloud should take Toxic Ignition reaction damage.
   - Fire Field Dev Vision should show `hazard_rx = registry: toxic_ignition` when the field triggers it.

## Regression checks

- Normal Fire Field burning still works.
- Normal Poison Cloud poisoning still works.
- Wind Gust still pushes/staggers enemies.
- Wind Gust hazard contact still finds hazards through the backup group scan.
- Generic chemistry still works:
  - Fire + oily
  - Lightning + wet
  - Ice + wet
  - Force + frozen

## Notes

The hazard methods are not deleted. This is intentional.

The registry now owns the relationship table, while individual hazards keep their effect code. That means future rules can say things like:

```text
slash x grass -> cut_grass
bludgeon x ice -> shatter
fire x vines -> burn_vines
water x fire_field -> dampen_flames
```

without hardcoding those relationships into every action script.
