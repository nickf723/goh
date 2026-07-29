# Divine Specials v1

## Purpose

Divine Specials replace the earlier one-action Invocation concept with a shared super-attack system inspired by multiplayer action-game Specials.

Grace does not spend mana to ask a patron for one ordinary attack. She builds one global `Divine Charge`, selects any unlocked Divine Special, and spends that charge on an effect powerful enough to change the shape of an encounter.

The Warlock action ladder is now:

```text
Divine Special
A charged patron power with a major battlefield effect

Manifestation
An autonomous patron companion using the complete character kit

Divine Incarnation
The stable player body becomes the patron and uses the complete character kit
```

`Invocation` may remain the lore verb for calling a Special, but the gameplay object is a `DivineSpecialDefinition`, not an ordinary weapon attack wrapped in a summon animation.

## Shared Divine Charge

The standard player owns:

```text
Player/DivineSpecialController
Player/DivineSpecialHUD
```

The controller has one charge pool shared by every patron and every unlocked Special.

```text
0 charge                              100 charge
[--------------------]  ->  [####################]
                                  Special ready
```

Using a Special spends its required charge, currently the full 100 points. Recharge then uses the selected Special's authored recharge time.

The v1 recharge sources are:

- passive recovery over the Special's authored recharge period;
- connected weapon attacks;
- additional charge for Heavy attacks;
- additional charge for deeper weapon sequences;
- successful Elemental Authority spell casts.

The charge belongs to Grace's stable player anchor. It therefore survives:

- equipment changes;
- changing the selected Special;
- Divine Incarnation;
- returning from Divine Incarnation.

Switching patrons cannot reveal a fresh hidden meter.

## Definitions and unlocks

Each Special is a `DivineSpecialDefinition` resource containing:

- patron and Special identity;
- player-facing description and tags;
- progression unlock ID;
- targeting mode;
- performer mode;
- effect scene;
- target range and area radius;
- active duration and safety timeout;
- activation lock and protection window;
- required charge;
- recharge time.

Ruvia's first three unlock IDs are:

```text
divine_special.ruvia.caldera_drop
divine_special.ruvia.wildfire_procession
divine_special.ruvia.hearth_first_flame
```

They are debug-available in editor and debug builds. Production access still requires the corresponding progression unlock.

All unlocked Specials remain available. The system does not require the player to equip two and abandon the rest.

## Performer resolution

A Special decides whether it needs a patron projection or can use the current player body.

| Current state | Result |
|---|---|
| Grace active | Ruvia appears as a brief wire projection while the effect resolves |
| Ruvia incarnated | The stable player body is the performer, so no duplicate Ruvia appears |
| Ruvia manifested | The autonomous manifestation is dismissed before the player-controlled Special begins |
| Another patron later manifested | The active manifestation is dismissed in v1 before the selected Special begins |

The player camera, health anchor, inventory, quests, and save identity never transfer to the Special effect.

## Ruvia Special catalog

### Caldera Drop

```text
Type: Burst / stance break / emergency clear
Recharge: 65 seconds before combat acceleration
Targeting: Lock-on target or aimed ground
```

Ruvia descends into the selected point and produces a large radial eruption.

The impact:

- deals heavy Fire health damage;
- deals very high stance damage;
- launches enemies near the center;
- applies strong Burning;
- clears hostile light projectiles in the blast;
- leaves an ally-safe Fire crater for several seconds.

Damage and force decline from the inner crater toward the outer ring.

### Wildfire Procession

```text
Type: Traveling area control
Recharge: 78 seconds before combat acceleration
Targeting: Aim direction
```

A line of eight eruptions marches away from Grace.

Each eruption:

- damages and Burns nearby enemies;
- applies upward and forward force;
- clears hostile projectiles near that segment;
- leaves a short-lived ally-safe Fire Field.

The complete line creates temporary terrain rather than one enlarged explosion. It is strongest in corridors, advancing encounters, and clustered formations.

### Hearth of the First Flame

```text
Type: Sustained protective domain
Recharge: 95 seconds before combat acceleration
Targeting: Grace's position
Duration: 10 seconds
```

Ruvia establishes a large Fire domain centered on Grace.

While active, the Hearth:

- prevents direct Fire health and stance damage to Grace;
- repeatedly removes Burning from Grace;
- restores Grace's stance over time;
- sustains Burning on enemies inside the domain;
- clears hostile projectiles entering the domain;
- periodically flares existing Fire Fields inside it.

The Hearth uses Fire as shelter, territory, and pressure rather than only burst damage.

## Friendly-fire and cleanup contract

All Ruvia Special effects use the shared ally filter.

They do not treat the following as targets:

- Grace;
- the active performer;
- player-group actors;
- friendly actors;
- friendly manifestations.

Special-created Fire terrain uses the ally-safe manifested Fire Field implementation. Enemy Burning and Fire reactions remain active.

Every Special has an action timeout. Cleanup occurs on:

- normal completion;
- explicit cancellation;
- player defeat;
- Divine Incarnation transition;
- return from Divine Incarnation;
- Manifestation startup;
- scene exit;
- lost or invalid effect actors.

A failed validation or invalid scene does not consume Divine Charge. Charge is spent only after an effect is configured and agrees to begin.

## Debug controls

```text
F11          Activate the selected Divine Special
Shift + F11  Cycle to the next unlocked Divine Special
F6           Restore full Divine Charge

F9           Grace <-> playable Ruvia
F10          Summon or dismiss autonomous Ruvia
F7           Restore showcase mana
F8           Reset the animation showcase
```

The production input and radial selection interface remain future work. The debug controls intentionally exercise the complete definition and execution path rather than bypassing it.

## Showcase

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

The eastern Divine Specials range contains:

- a marked Caldera Drop center;
- a large Hearth radius;
- an eight-segment Wildfire Procession lane;
- several clustered training targets;
- F11, Shift+F11, and F6 instructions.

The player HUD shows:

- selected patron and Special;
- Divine Charge percentage;
- ready, recharging, or active state;
- last completion result;
- targets hit;
- hostile projectiles cleared;
- persistent Fire fields spawned.

Suggested review:

1. Use Caldera Drop against the central cluster and inspect the inner and outer impact rings.
2. Walk through the crater afterward and confirm Grace remains safe while enemies Burn.
3. Cycle to Wildfire Procession and aim down the marked lane.
4. Confirm the eruptions advance in sequence rather than appearing simultaneously.
5. Cycle to Hearth of the First Flame.
6. Stand in Fire, spend stance, and let hostile projectiles enter the domain.
7. Confirm the domain protects Grace, restores stance, and pressures enemies.
8. Press F10, then activate a Special. Autonomous Ruvia should dismiss before the Special starts.
9. Press F9 to incarnate Ruvia and activate Caldera Drop. No duplicate patron projection should appear.
10. Return to Grace and confirm the same shared Divine Charge remains in use.

## Regression

Focused scene:

```text
scenes/tests/divine_specials_smoke_test.tscn
```

Expected Output marker:

```text
DIVINE_SPECIALS_SMOKE_TEST: PASS
```

The regression covers:

- installation on the shared player;
- all three Ruvia definitions;
- charge award, refill, consumption, and readiness;
- Caldera Drop impact and crater creation;
- Wildfire Procession eruption and field counts;
- Hearth Fire immunity, Burning cleanup, and stance recovery;
- safe cancellation and metadata cleanup;
- automatic Manifestation dismissal;
- Incarnated Ruvia as the direct performer;
- restoration to Grace after the Incarnation test.

The main Godot validation workflow runs this scene after the Avatar Control Driver and Manifestation regression.

## Deliberate v1 boundaries

- Final Ruvia character art, animation, VFX, audio, and camera choreography are not present.
- The patron projection uses the diagnostic wire body.
- Special charge is runtime state and is not yet persisted in the save slot.
- Combat recharge currently observes connected weapon attacks and Elemental Authority casts, not every possible reaction or perfect-defense event.
- The production Special radial and controller bindings are not implemented.
- Enemy AI does not yet recognize Special telegraphs or deliberately flee domains.
- Projectile clearing scans current projectile actors and is prototype-scale rather than the final optimized registry.
- Special balance and recharge times are first-pass values.
- Phoenix Oath and later Ruvia Specials remain future unlocks.
- A second patron will prove the data model beyond Fire.
