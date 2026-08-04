# Animal Bonding and Persistence v1

## Purpose

This layer completes the first named-animal relationship loop:

`personality → perception → memory → relationship → changed behavior → persistence`

A relationship is no longer only a number displayed above an animal. Trust and learned fear now alter voluntary movement, positive interactions consume real inventory resources, gameplay events can help or damage a bond, and a stable animal identity survives scene and game reloads.

## Named identity

`BondedAnimalActor` extends `GenericAnimalActor` with a stable `persistent_animal_id`.

The Animal Behavior Lab uses:

- `animal_behavior_lab:mallow`
- `animal_behavior_lab:bramble`
- `animal_behavior_lab:ash`
- `animal_behavior_lab:cinder`

A production scene can assign any stable world-facing ID. Re-instantiating an actor with the same ID restores the saved relationship.

## Persistent bond store

`AnimalBondStore` is a root-level service created on demand. It survives scene changes and writes named records to:

`user://goh_named_animal_bonds.json`

Each record contains:

- Stable animal ID
- Display name
- Species
- Personality profile
- Trust
- Familiarity
- Fear association
- Peaceful exposure
- Last interaction
- Interaction count
- Bonded state
- Follow or stay preference
- Help-event count
- Harm-event count

The store normalizes and clamps imported values before exposing them to actors.

## Inventory-backed feeding

The new `Field Treat` is a real inventory item with the `animal_food`, `food`, `bonding`, and `life` tags.

Feeding now:

1. Checks that Grace is close enough.
2. Requires at least one Field Treat.
3. Consumes one item from `GameState` inventory.
4. Applies the Feed relationship event.
5. Saves the named animal record immediately.

The lab supplies an initial testing stock and can add more through its bonding panel.

## Behavioral consequences

Relationship state changes ambient execution without adding separate species-specific AI trees.

### Wary

A wary animal watches Grace and backs away when she enters its comfort distance.

### Curious

A curious animal voluntarily approaches Grace, but stops outside its current personal space.

### Bonded and following

A bonded animal can convert an eligible Idle decision into `Follow Grace`.

It:

- Moves toward Grace when she is too far away.
- Stops at a loose companion distance.
- Backs away slightly if Grace crowds through it.
- Continues using perception and last-known-position memory.

The Follow / Stay preference is persistent.

### Afraid and hostile

Existing fear and hostility behavior remains authoritative. An unbonded afraid animal flees, while hostile animals can hunt and alert allies. A bonded animal still reacts if Grace explicitly adopts a threatening posture or harms it.

## Bond requirements

The first prototype bond requires:

- Trust at least 58%
- Familiarity at least 45%
- Fear association no higher than 30%
- Current fear no higher than 35%
- Grace standing nearby in a peaceful posture

Three successful Feed interactions are sufficient to make the lab sheep eligible when no fresh fear is present.

Bonding raises the relationship into a stable trusting range and enables Follow by default.

## Gameplay event bridge

`report_grace_event()` lets future gameplay systems report consequences without pretending every event was a menu interaction.

The initial events are:

- `help`
- `heal`
- `rescue`
- `attack`
- `damage`
- `chase`
- `threaten`

Help, healing, and rescue improve the relationship and reduce fear. Attacks, damage, chasing, and threatening behavior damage trust, reinforce fear, and may alert nearby animals.

## Lab controls

The original perception panel remains on the left. A new right-side bonding panel provides mouse-clickable and controller-focusable controls for:

- Bond Selected
- Follow / Stay
- Help / Heal
- Report Attack
- Add 6 Treats
- Clear This Bond
- Save Bonds
- Reload Bonds

Reset Lab restores positions and drives while preserving saved named relationships. Clear This Bond explicitly removes the selected animal's persistent record.

## Automated validation

Scene:

`res://scenes/tests/animal_bonding_persistence_smoke_test.tscn`

Expected output:

`ANIMAL_BONDING_PERSISTENCE_SMOKE_TEST: PASS`

The regression verifies:

- Field Treat registration and inventory consumption
- Trust and familiarity growth through feeding
- Bond eligibility
- Bond creation
- Persistent named records
- Follow action selection
- Physical distance-closing while following Grace
- Disk save and reload
- Restoration into a newly instantiated actor with the same identity
- Persistent trust restoration
- Harm events damaging trust and updating history
- The playable lab using the bonding extension
