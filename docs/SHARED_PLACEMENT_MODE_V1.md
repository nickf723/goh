# Shared Placement Mode v1

## Purpose

Persistent abilities now share one placement session after their context action is selected. Recorded objects, Artificer parts, and saved contraptions no longer own separate gameplay control grammars.

The ability context menu chooses what Grace wants to place. `PlayerSharedPlacementController` owns how placement is controlled.

## Universal controller grammar

- Right stick: aim the camera and preview
- D-pad Up / Down: move the preview farther or nearer
- D-pad Left / Right: cycle the prepared variant
- L / R: rotate the preview
- Cast or A: confirm
- B: cancel

Keyboard and mouse:

- Q / E or mouse wheel: depth
- Z / X: cycle variant
- R: rotate; Shift+R rotates backward
- Cast, Enter, or left click: confirm
- Escape or right click: cancel

## Runtime ownership

`PlayerAbilityContextRouter` installs one `SharedPlacementController` beside the shared ability context menu.

A placement action returns:

```gdscript
{
    "ok": true,
    "begin_shared_placement": "recorded_object",
}
```

The context closes, then the shared placement controller starts a provider session.

The controller owns:

- controller, keyboard, and mouse placement input
- movement and ordinary-action locking
- placement HUD presentation
- session lifecycle and cleanup
- depth, rotation, variant, confirm, and cancel counters
- controller handoff back to ordinary gameplay

Providers own:

- preview construction and updates
- placement targeting and validation
- variant definitions
- mana costs and active limits
- commit behavior
- provider-specific cleanup

## Provider contract

```gdscript
func begin_shared_placement(placement_id: String) -> Dictionary
func get_shared_placement_state(placement_id: String) -> Dictionary
func adjust_shared_placement_depth(placement_id: String, direction: int) -> Dictionary
func rotate_shared_placement(placement_id: String, direction: int) -> Dictionary
func cycle_shared_placement_variant(placement_id: String, direction: int) -> Dictionary
func confirm_shared_placement(placement_id: String) -> Dictionary
func cancel_shared_placement(placement_id: String) -> void
```

Providers may also implement `confirm_shared_placement_at()` for deterministic scripted sequences and regressions.

## Current providers

### Recorded Object

Placement id: `recorded_object`

The provider supplies recorded blueprint cycling, preview validation, mana cost, per-blueprint active limit, and reproduction.

### Artificer Assembly

Placement id: `artificer_part`

The session remains active after a part is attached, allowing Grace to keep building. D-pad Left and Right cycle unlocked parts. B exits placement without deleting the draft.

### Deploy Contraption

Placement id: `artificer_deploy`

The provider cycles saved starter and custom blueprints, validates the complete build footprint, deploys the selected contraption, then closes the placement session.

## Compatibility

Legacy manager input routing remains as a fallback for old labs or scripts that begin manager placement directly. Normal persistent-ability gameplay enters through the shared placement controller first.

The weapon input bootstrap keeps legacy recorded-object controller listeners disabled while a shared placement session is active. The contextual control router delegates physical controller buttons to the shared placement controller before inspecting old managers.

## Regression

`res://scenes/tests/persistent_ability_context_providers_smoke_test.tscn`

The regression verifies all three placement families through one controller, including context handoff, variant cycling, depth, rotation, continuous assembly, cancellation, movement/action locks, actual placement, and ownership cleanup.
