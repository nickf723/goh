# Elemental Alchemy v1

Elemental Alchemy turns gathered world ingredients and elemental spell knowledge into persistent, usable quick items.

## Laboratory

Run:

```text
scenes/levels/prototypes/prototype_elemental_alchemy_lab_v1.tscn
```

The apothecary contains five renewable ingredient stations, five elemental treatment stations, and one cauldron. Interact with a treatment station to prepare the cauldron, then interact with the cauldron to choose two ingredients and brew.

## Controls

- Move and camera: normal player controls
- Interact: collect an ingredient, prepare a treatment, or open the cauldron
- Menu Up / Down: move through ingredients and actions
- Confirm / Interact: add the highlighted ingredient or activate an action
- Cancel: remove the last selected ingredient; cancel again to close
- F8: reset the laboratory, ingredient inventory, crafted outputs, and discoveries

## Ingredients and traits

| Ingredient | Traits |
| --- | --- |
| Life Bloom | Life, Body |
| Springwater | Water, Cleanse |
| Echo Reed | Sound, Air |
| Frost Salt | Ice, Poison |
| Spark Ore | Metal, Lightning |

## Discoverable recipes

| Ingredients | Treatment | Result |
| --- | --- | --- |
| Life Bloom + Springwater | Fire | Healing Potion |
| Echo Reed + Springwater | Air | Resonance Tonic |
| Frost Salt + Life Bloom | Ice | Frost Vigor Draught |
| Frost Salt + Springwater | Water | Clarifying Antidote |
| Spark Ore + Springwater | Lightning | Conductive Elixir |

A correct brew consumes one of each ingredient, records the discovery in saved game state, creates the real inventory item, and assigns it to the first open quick-belt slot. Recipe order does not matter.

Incorrect ingredient pairs or treatments create unstable sludge and consume the attempt. If the crafted item's stack is full, the ingredients are preserved.

## Persistence

Ingredient counts, crafted potion counts, quick-belt assignments, and recipe discovery flags use the existing GameState save data. Ingredient pickups replenish when the laboratory is reset; crafted potions do not refill at beds.

## Smoke test

```text
scenes/tests/elemental_alchemy_smoke_test.tscn
```

The smoke test checks order-independent recipe keys, elemental treatment validation, and registration of all crafted potions in the quick-item catalog.
