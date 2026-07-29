# Divine Specials v1.2

## Purpose

Divine Specials are shared super attacks with major battlefield effects. Grace builds one global `Divine Charge`, selects any unlocked patron Special, and spends charge only when she deliberately activates it.

The Warlock action ladder is:

```text
Divine Special
A charged patron power with a major battlefield effect

Manifestation
An autonomous patron companion using the complete character kit

Divine Incarnation
The stable player body becomes the patron and uses the complete character kit
```

`Invocation` may remain the lore verb, but the gameplay object is a `DivineSpecialDefinition` rather than an ordinary attack wrapped in a summon animation.

## Shared Divine Charge

The standard player owns:

```text
Player/DivineSpecialController
Player/DivineSpecialHUD
Player/DivineSpecialInputRouter
Player/DivineSpecialRadialMenu
```

The controller has one charge pool shared by every patron and unlocked Special.

```text
0 charge                              100 charge
[--------------------]  ->  [####################]
                                   Special ready
```

Using a Special spends its required charge, currently the full 100 points. Recharge uses the selected Special's authored recharge time.

Current recharge sources include:

- passive recovery;
- connected weapon attacks;
- additional charge for Heavy attacks;
- additional charge for deeper weapon sequences;
- successful Elemental Authority casts.

The charge belongs to Grace's stable player anchor and survives equipment changes, changing the selected Special, Divine Incarnation, and returning from Incarnation. Switching patrons cannot reveal a fresh hidden meter.

## Definitions and unlocks

Each `DivineSpecialDefinition` contains:

- patron and Special identity;
- description and tags;
- progression unlock ID;
- targeting and performer modes;
- effect scene;
- range and area radius;
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

They are debug-available in editor and debug builds. Production access still requires progression unlocks.

All unlocked Specials remain selectable. The system does not require the player to equip two and abandon the rest.

## Performer resolution

| Current state | Result |
|---|---|
| Grace active | Ruvia appears as a brief projection while the effect resolves |
| Ruvia incarnated | The stable player body performs the Special, avoiding duplicate Ruvia actors |
| Ruvia manifested | The autonomous manifestation is dismissed before activation |
| Another patron manifested | The active manifestation is dismissed in v1 before activation |

The player camera, health anchor, inventory, quests, and save identity never transfer to the Special effect.

## Ruvia Special catalog

### Caldera Drop

```text
Type: Burst / stance break / emergency clear
Recharge: 65 seconds before combat acceleration
Targeting: Lock-on target or aimed ground
```

Ruvia descends into the selected point and produces a radial eruption. Damage and force decline from the inner crater toward the outer ring.

The impact:

- deals heavy Fire damage;
- deals very high stance damage;
- launches enemies near the center;
- applies strong Burning;
- clears hostile light projectiles;
- leaves an ally-safe Fire crater.

### Wildfire Procession

```text
Type: Traveling area control
Recharge: 78 seconds before combat acceleration
Targeting: Aim direction
```

A line of eight eruptions marches away from Grace. Each eruption damages and Burns nearby enemies, applies force, clears hostile projectiles, and leaves a temporary ally-safe Fire Field.

### Hearth of the First Flame

```text
Type: Sustained protective domain
Recharge: 95 seconds before combat acceleration
Targeting: Grace's position
Duration: 10 seconds
```

While active, the Hearth:

- prevents direct Fire health and stance damage to Grace;
- removes Burning from Grace;
- restores stance over time;
- sustains Burning on enemies inside the domain;
- clears hostile projectiles entering the domain;
- flares existing Fire Fields inside it.

## Friendly-fire and cleanup contract

Ruvia's effects use the shared ally filter and do not target Grace, the active performer, player-group actors, friendly actors, or friendly manifestations.

Special-created Fire terrain uses the ally-safe manifested Fire Field implementation. Enemy Burning and Fire reactions remain active.

Every Special has an action timeout. Cleanup occurs on normal completion, explicit cancellation, player defeat, Incarnation transitions, Manifestation startup, scene exit, and lost or invalid effect actors.

A failed validation or invalid scene does not consume Divine Charge. Charge is spent only after an effect is configured and agrees to begin.

## Controller controls

D-pad Down owns Divine Specials outside Focus.

```text
Quick tap Down           Attempt to activate the selected Special
Hold Down                Open the Divine Special selector
Right stick while held   Select an unlocked Special
Release after holding    Keep the selection and close without activating
B / Circle while held    Cancel without spending charge
```

The selector may open at any charge level. This allows the player to prepare the next Special while Divine Charge is rebuilding.

Selection and activation are deliberately separate:

- changing selection consumes no charge;
- releasing a held selector never activates;
- a later quick tap attempts activation;
- a quick tap below the required charge is rejected with feedback;
- only a successful activation spends charge.

While the full Focus spell menu is open, D-pad Down belongs to spell navigation and the Divine router remains inactive.

The radial uses the shared menu action lock and slows time to `0.35`. Movement remains governed by the existing Focus-menu preference, while attacks, dodges, interaction, and item use remain blocked. Cancellation and release restore the previous menu state and time scale.

## Debug controls

```text
F11           Activate the selected Divine Special
Shift + F11   Cycle to the next unlocked Divine Special
F6            Restore full Divine Charge

F9            Grace <-> playable Ruvia
F10           Summon or dismiss autonomous Ruvia
F7            Restore showcase mana
F8            Reset the animation showcase
```

The keyboard shortcuts exercise the same definition and execution paths rather than bypassing the player-facing system.

## Showcase review

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

Suggested review:

1. Activate Caldera Drop against the central cluster.
2. Confirm Grace remains safe in the resulting Fire crater.
3. Refill, hold D-pad Down, select Wildfire Procession, and release.
4. Confirm selection changes without activation or charge consumption.
5. Quick tap D-pad Down to activate Wildfire Procession.
6. Repeat the held selection while charge is still rebuilding.
7. Select Hearth, release, refill, then quick tap to activate it.
8. Cancel an open selector with B or Circle and confirm selection and charge remain stable.
9. Test Manifested and Incarnated Ruvia performer resolution.

## Regression

Effect and charge scene:

```text
scenes/tests/divine_specials_smoke_test.tscn
DIVINE_SPECIALS_SMOKE_TEST: PASS
```

Broad controller grammar scene:

```text
scenes/tests/divine_special_input_smoke_test.tscn
DIVINE_SPECIAL_INPUT_SMOKE_TEST: PASS
```

Selection quirks scene:

```text
scenes/tests/controller_selection_quirks_smoke_test.tscn
CONTROLLER_SELECTION_QUIRKS_SMOKE_TEST: PASS
```

The combined regressions cover installation, all three Ruvia definitions, charge behavior, effects, friendly safety, performer resolution, controller isolation, handed shoulder presets, Focus navigation, selection while recharging, selection-only held release, low-charge rejection, ready tap activation, radial cancellation, and time restoration.

## Deliberate v1 boundaries

- Final Ruvia character art, animation, VFX, audio, and camera choreography are not present.
- The patron projection uses the diagnostic wire body.
- Special charge is runtime state and is not yet persisted in the save slot.
- Recharge does not yet observe every possible reaction or perfect-defense event.
- Battlefield targeting previews are not implemented.
- Final platform glyph assets are not implemented.
- Enemy AI does not yet deliberately flee Special telegraphs or domains.
- Projectile clearing remains prototype-scale.
- Balance and recharge values are first-pass values.
- Phoenix Oath and later Ruvia Specials remain future unlocks.
- A second patron will prove the data model beyond Fire.
