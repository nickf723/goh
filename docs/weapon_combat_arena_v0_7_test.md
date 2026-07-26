# Weapon Combat Arena v0.8 — Combo Laboratory Test

Run:

```text
scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn
```

## Player-facing goal

The permanent Weapon Combat Arena is now a progression-safe combat laboratory:

```text
enter arena
→ snapshot real progression
→ temporarily unlock all catalog equipment, upgrades, and Master weapon ranks
→ test grounded and aerial combo routes with automatic resource refill
→ leave arena
→ restore the entry snapshot
```

No new combat input is required. The arena reuses the configured semantic `LIGHT`, `HEAVY`, `DODGE`, movement, jump, lock-on, spell, and reset actions.

## Entry sandbox

1. Enter the arena with any ordinary save state.
2. Confirm the HUD reports:
   - all sixteen weapon classes mastered;
   - all catalog upgrades unlocked;
   - combat resources set to auto-refill;
   - entry progression will be restored when the scene closes.
3. Equip the Practice Sword, Training Hammer, and Training Spear from their racks.
4. Confirm each equipped weapon displays `MASTER` immediately.
5. Confirm Dash and all three aerial techniques work without earning mastery or remastering the weapon first.

## Weapon-preserving reset

1. Equip the Training Hammer or Training Spear.
2. Press the arena reset action or use the reset console.
3. Confirm Grace returns to the starting position.
4. Confirm targets and live enemies reset.
5. Confirm the currently equipped weapon remains equipped.
6. Confirm mastery, upgrade access, and the combo checklist remain available.
7. Repeat several resets and confirm the arena never forces the Practice Sword unless no weapon exists.

## Grounded combo checklist

The HUD derives its route list from the equipped weapon's authored moveset graph.

1. Equip each of the three implemented weapons in turn.
2. Confirm the grounded route list changes to match that weapon.
3. Perform the displayed `L` and `H` sequences.
4. Confirm a completed displayed route changes from an empty box to a check mark.
5. Confirm route completion remains checked after resetting targets.
6. Confirm switching weapons preserves the completed routes for the previous weapon during the same arena session.
7. Confirm repeated or cyclic branches display a loop marker instead of growing forever.

The guide intentionally caps itself at ten representative routes and six attacks per route so cyclic movesets cannot flood the HUD.

## Context technique checklist

For each implemented weapon, complete:

1. **Dash technique:** attack during an active dodge.
2. **Neutral aerial:** jump and press Light without movement input.
3. **Forward aerial:** jump, hold movement, and press Light.
4. **Plunging heavy:** jump and press Heavy, then land.

Confirm:

- the active technique name appears in the attack telemetry;
- its checklist box becomes checked;
- successful aerial Light hits preserve height briefly;
- forward aerial hits pursue the struck target;
- missed aerial attacks do not grant free hang time;
- plunging Heavy creates its landing impact;
- interrupted plunges do not create a delayed impact.

## Launch and cleave target cluster

Use the three added targets under `LAUNCH • AERIAL • CLEAVE LAB`.

Confirm:

- a qualifying grounded Heavy finisher launches the center target;
- Grace can pursue and strike the launched target with aerial Light attacks;
- the left and right targets provide readable multi-target spacing for wide attacks;
- Hammer, Sword, and Spear geometry still feels distinct;
- launched targets fall, land, and reset cleanly;
- F8 restores all three targets to their authored positions.

## Automatic combat resources

1. Repeat long weapon strings until they would normally exhaust Stamina.
2. Cast spells between weapon branches.
3. Allow a live enemy to damage Grace.
4. Confirm Health, Stamina, Mana, and Stance refill automatically.
5. Confirm the resource refill does not reset the current weapon, combo checklist, enemies, or target positions.

## Progression restoration

This is the safety-critical test.

1. Before entering, note Grace's current weapon mastery, owned equipment, equipped items, unlocks, Focus, and weapon infusion.
2. Enter the arena and confirm the temporary sandbox powers appear.
3. Switch weapons and complete several techniques.
4. Leave the arena through the Development Control Center or another scene transition.
5. Confirm the noted entry values return exactly.
6. Re-enter the arena and confirm the sandbox is granted again from the newly captured entry state.

Arena activity must not permanently award Master ranks, catalog equipment, upgrade unlocks, Focus, or a different weapon infusion.

## Stance and critical regression

The existing v0.7 combat loop remains active.

Confirm:

- weapon hits deplete stance before damaging health where configured;
- stance break opens the timed critical vulnerability;
- the next valid weapon melee strike consumes the opening;
- a missed swing does not consume the opening;
- targets recover if Grace does not capitalize;
- Sword, Hammer, and Spear retain their distinct critical profiles;
- live Goblin and Gremlin enemies still attack, stagger, recover, disappear, and respawn normally.

## Existing combat regression

Confirm:

- Light/Heavy buffering and branch selection still work;
- spell and dodge cancel windows remain unchanged;
- lock-on and facing assistance remain usable;
- hit geometry and one-hit-per-target behavior remain unchanged;
- weapon racks still switch weapons;
- the Church Trial remains completable with ordinary story progression outside the arena.

## Automated coverage

The registered `weapon_moveset_smoke_test.tscn` now verifies:

- all existing Sword, Hammer, and Spear moveset graphs and payload contracts;
- weapon critical identity and the stance-critical loop;
- the arena sandbox reports every weapon class, equipment definition, and catalog unlock;
- all weapon classes receive maximum mastery inside the sandbox;
- all equipment and catalog unlocks are temporarily granted;
- combat resources refill;
- stats, owned equipment, equipped items, mastery, and unlock snapshots restore afterward.

## Known limitations

- Only Sword, Hammer, and Spear currently have equipable production weapon resources and authored combo graphs.
- The checklist records authored grounded routes and the four shared context techniques; it does not grade timing quality, whiffs, spell cancels, or freeform improvisation.
- The HUD displays at most ten representative grounded routes with a maximum depth of six attacks.
- Presentation remains procedural and transform-driven rather than final skeletal animation.
- Blocking, parrying, boss-specific break rules, final balance, and bespoke execution animations remain deferred.
