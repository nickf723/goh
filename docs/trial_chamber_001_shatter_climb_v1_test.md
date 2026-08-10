# Trial Chamber 001: Shatter & Climb v1 Manual Test

## Purpose

`Shatter & Climb` is the first compact trial in the new isolated-puzzle development format.

The room deliberately removes open-world set-design noise and asks one question:

> Given a small fixed toolset, can Grace discover and execute more than one coherent solution to the same spatial goal?

Scene:

```text
res://scenes/levels/prototypes/trial_chamber_001_shatter_climb_v1.tscn
```

The chamber is intentionally placeholder-simple. Judge puzzle readability, tool expression, movement, camera behavior, and solution satisfaction rather than final art.

## Fixed trial loadout

Grace receives only:

```text
Weapon: Training Hammer
Spell 1: Water Jet
Spell 2: Ice Lance
```

The trial disables automatic double jump, hover, and Flight so the room cannot be bypassed by development progression state.

Mana and Stamina regenerate during the trial so experimentation is cheap.

## Objective

Reach the glowing upper seal at the back of the chamber.

Two intentionally supported routes exist. Only one is required.

## Left route: Water → Ice

- Inspect the cyan lane on the left.
- Confirm the gap contains a flooded crossing with no starting traversal collision.
- Cast Water onto the crossing if needed to establish Wet state.
- Cast Ice onto the same crossing.
- Confirm it becomes a visible, solid ice bridge.
- Cross it.
- Climb the left stair run to the upper platform.
- Reach the gold seal.
- Confirm the trial completes.

The route should feel like manipulating the environment, not entering a password.

## Right route: Ice → Heavy

- Reset the chamber.
- Take the stone-marked right route.
- Climb to the fractured masonry wall.
- Hit it normally before freezing it and confirm it resists.
- Cast Ice onto the masonry.
- Confirm the wall becomes visibly frozen/brittle.
- Use a Heavy Hammer attack.
- Confirm the frozen wall shatters/withdraws and opens the route.
- Continue up the right stair run.
- Reach the gold seal.
- Confirm the trial completes.

The important read is:

```text
ordinary fractured wall = absorbs force
frozen fractured wall = coherent brittle mass = shatterable
```

## Reset behavior

Use the existing `RESET` / `restart_scene` development action.

Confirm reset:

- returns Grace to the entrance;
- restores Health, Mana, Stamina, and Stance;
- restores the flooded crossing;
- restores the masonry seal;
- clears trial completion;
- keeps the fixed Water / Ice / Hammer loadout.

Falling below the chamber also returns Grace to the start rather than requiring a scene reload.

## Creative review

The first playtest should answer these questions:

1. Is the upper goal immediately readable without a floating solution tutorial?
2. Do the cyan-water lane and fractured-stone lane suggest different experiments without spelling them out?
3. Does Water → Ice feel physically understandable?
4. Does Ice → Heavy feel like a satisfying compound interaction rather than an arbitrary combo lock?
5. Is either route much easier, clearer, or more enjoyable than the other?
6. Does the fixed loadout make experimentation easier than carrying Grace's full spell library?
7. Do the room dimensions give the camera enough breathing room?
8. Are the stair runs comfortable with Grace's current movement controller?
9. After solving one route, do you naturally want to reset and test the other?
10. What unintended solution do you try first?

Unexpected solutions are valuable information. If a solution uses the supplied tools coherently and does not trivialize every future trial, treat it as evidence about the sandbox before treating it as a bug.

## Automated regression

```text
res://scenes/tests/trial_chamber_001_shatter_climb_smoke_test.tscn
```

The regression checks:

- compact chamber structure;
- exact two-spell fixed loadout;
- Training Hammer assignment;
- aerial bypasses disabled;
- Water + Ice activates the left crossing;
- Ice alone primes but does not clear the masonry;
- Heavy force clears frozen masonry;
- either solved route can satisfy the upper goal;
- reset restores both mechanisms and runtime completion state.

## Promotion status

Trial Chamber 001 begins as an experimental authored-content scene rather than a new general framework. Once the chamber format survives manual playtesting, promote it into the permanent feature registry and use the lessons from this room to author Trial 002.
