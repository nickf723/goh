# Gameplay Effects v1

Gameplay effects are reusable rules granted by arbitrary sources. Equipment is the first producer, but consumers do not know or care where an effect originated.

## Contract

1. `GameplayEffectCatalog` defines named effects as channel modifiers.
2. The gameplay-effect service tracks sources and their effect IDs; `GameplayEffectAccessScript` provides compile-safe access.
3. Gameplay systems resolve values through named channels.
4. Removing or replacing a source immediately removes its contribution.

A source may be permanent or timed:

```gdscript
const GameplayEffectAccessScript = preload("res://scripts/effects/gameplay_effect_access.gd")

var effect_ids: Array[String] = ["wayfarer_stride"]
var tags: Array[String] = ["potion", "movement"]
GameplayEffectAccessScript.set_effect_source("potion:swift_tea", effect_ids, 20.0, tags)
```

Removing a source is explicit:

```gdscript
GameplayEffectAccessScript.remove_effect_source("potion:swift_tea")
```

Sources can also be cleared by tag:

```gdscript
GameplayEffectAccessScript.remove_sources_with_tag("food")
```

## Channels in v1

- `stamina_recovery_rate`
- `mana_cost`
- `stamina_cost`
- `focus_cost`
- `stance_damage_taken`
- `guard_stamina_cost`
- `health_restore`
- `shop_buy_price`
- `shop_sell_price`
- `currency_reward`

A consumer resolves a value without equipment-specific logic:

```gdscript
var recovery_rate := GameplayEffectAccessScript.modify_float("stamina_recovery_rate", base_rate)
var mana_cost := GameplayEffectAccessScript.modify_int("mana_cost", base_cost, "ceil")
```

## Current equipment sources

- Traveler's Coat → Wayfarer's Stride
- Apprentice Robe → Apprentice's Flow
- Ironweave Jacket → Ironweave Guard
- Vital Knot → Vital Restoration
- Resonance Charm → Resonant Focus
- Merchant's Token → Merchant Rapport
- Lucky Shard → Fortune's Favor

## Reuse targets

Future potions, food, spells, blessings, curses, weather, terrain, quest rewards, difficulty rules, and enemy auras should grant catalog effects through a source ID instead of duplicating their arithmetic inside consumers.

Timed effects pause while gameplay is paused. Multipliers from multiple active sources compose multiplicatively; flat additions are summed before multiplication.
