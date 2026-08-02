# Recorded Object Spell and Global Context HUD v1

## Purpose

Recorded Objects now use the same prepare-then-cast rhythm as familiars and other configurable magic. Grace chooses a recorded pattern while the game is paused, equips `Reproduce Object` as a spell, and enters placement only when that spell is cast during gameplay.

Temporary mechanics no longer create unrelated HUD panels in whichever corner is still available. `GameplayContextHUD` owns one reserved strip above the quick-spell belt for:

- Recorded Object placement
- Soul Grasp manipulation
- Familiar summon and command notices
- Future short-lived contextual mechanics

The development proving ground may still display its own top-right telemetry panel. Normal field scenes use the shared context strip.

## Preparing a recorded object

A blueprint must already be recorded from a world object or development station.

### Magic

1. Open the full menu.
2. Open Magic.
3. Find `REPRODUCE OBJECT • PREPARED BLUEPRINT`.
4. Select Crate, Platform, Spring, or Blast Barrel.
5. Assign `Reproduce Object` to a quick-spell slot through the normal spell assignment workflow.
6. Close the menu.
7. Select that spell and cast it.

The prepared blueprint persists with the save slot.

### Items

1. Open Items → Objects.
2. Select a recorded blueprint once to prepare it.
3. Confirm it again to close the menu and enter placement immediately.

This direct route remains useful when the player does not want to dedicate a quick-spell slot.

### Journal blueprint record

1. Open Journal → Blueprints.
2. Select the recorded object once to inspect its learned record.
3. Confirm the same record again to close the menu and reproduce it.

Journal → Blueprints is currently the learned blueprint compendium. The core Codex still contains quests, challenges, achievements, and completion records; a dedicated Codex blueprint shelf is not part of this version.

## Reproduce Object controls

### Controller

- D-pad Up: move the preview farther away
- D-pad Down: move the preview nearer
- L: rotate 90 degrees left
- R: rotate 90 degrees right
- A: confirm placement
- B: cancel placement

The placement manager ignores controller inputs until a spell, menu record, or station deliberately enters placement mode. Normal combat retains the shoulder buttons.

### Keyboard and mouse

- V: begin or cancel placement for the prepared blueprint
- Q / E: move the preview nearer or farther
- R: rotate 90 degrees
- Left click: confirm placement
- Right click or Escape: cancel
- Mouse wheel: adjust placement depth

## Placement behavior

The context HUD reports:

- Prepared object name and icon
- Valid or invalid position
- Invalid placement reason
- Current depth offset
- Current rotation
- Context controls

The preview remains green on valid terrain and red when blocked, out of range, unsupported, or overlapping another active reproduction.

The spell itself has no upfront mana cost. The selected object's authored mana cost is paid only when placement is confirmed.

## Soul Grasp controls

Soul Grasp now uses the same manipulation language:

- D-pad Up / Down changes hold distance
- L / R rotates the held object
- Right stick aims
- Releasing Cast drops the target

The shared context HUD reports the held target and current distance. The older D-pad-left/right rotation mapping was removed.

## Familiar context

The same HUD can briefly report:

- Familiar summoned
- Familiar dismissed
- Familiar command changed

These are transient notices rather than permanent panels.

## Blast Barrel freeze repair

Recorded Blast Barrels no longer resolve every explosion, payload, enemy reaction, and chained barrel recursively inside one frame.

The new sequence is:

1. The initiating barrel marks itself spent immediately.
2. Its visual explosion appears.
3. Blast resolution runs on the next idle turn.
4. Nearby Recorded Objects are discovered from the authoritative SceneTree group.
5. Enemies and ordinary physics bodies are discovered through the physics overlap.
6. Each nearby dry barrel schedules one additional deferred detonation.
7. Wet barrels reject that request through their dampened-fuse guard.
8. The initiating barrel exits after its blast resolves.

Using both the SceneTree and physics overlap means a newly reproduced barrel can participate in a chain even before the physics server has registered its collision body.

Explosion payloads suppress further generic reaction recursion while still applying authored damage and force. `Engine.time_scale` remains unchanged.

## Suggested field test

1. Enter the Ruined Village or Church encounter.
2. Record or debug-unlock the Blast Barrel blueprint.
3. Prepare Blast Barrel in Magic.
4. Equip `Reproduce Object` to a quick-spell slot.
5. Cast the spell.
6. Move the preview with D-pad Up and Down.
7. Rotate it with L and R.
8. Place two barrels near one another.
9. Fire a Firebolt into the first barrel.
10. Confirm both barrels detonate in sequence and gameplay continues.
11. Place another barrel in water or apply Water first.
12. Fire a Firebolt and confirm the dampened barrel remains intact.
13. Equip Soul Grasp and verify the same depth and rotation controls.
14. Confirm the context panel appears above the quick-spell belt rather than behind the Divine Special wheel.

## Automated validation

Scene:

`res://scenes/tests/recorded_object_spell_context_smoke_test.tscn`

Expected output:

`RECORDED_OBJECT_SPELL_CONTEXT_SMOKE_TEST: PASS`

The regression validates:

- Reproduce Object as an ability channel
- Prepared blueprint selection
- Placement depth and rotation
- Global context HUD object mode
- Global context HUD Soul Grasp mode
- Safe Recorded Object actor creation
- Firebolt-style barrel impact
- Deferred barrel chain completion
- Continued process and physics frames
- Unchanged global time scale

The established interoperability regression separately validates ignition, extinguishing, wet freezing, frozen shatter, spring overcharge, conductive platforms, dampened fuses, buoyancy, and deferred barrel chains.
