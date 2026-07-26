# Airborne Presentation v1

Run:

```text
scenes/levels/prototypes/prototype_airborne_presentation_lab_v1.tscn
```

## Lab controls

- **F5:** Launch every target.
- **F6:** Apply an aerial follow-up to every target.
- **F7:** Apply a plunging hit and arm a ground bounce.
- **F8:** Reset the player and all targets.
- Normal weapon attacks, aerial techniques, weapon racks, and the reset console remain available.

The lab temporarily unlocks all catalog equipment, upgrades, and weapon mastery. Combat resources refill automatically, and the player's entry progression is restored when the scene closes.

## Presentation profiles

### Featherweight

- Fast multi-axis tumble.
- Strong airborne stretch and landing squash.
- Higher ground bounce.
- Faster landing recovery.
- Slower juggle-resistance buildup.

### Standard

- Moderate spin and readable falling silhouette.
- Balanced squash, bounce, hitstun, and recovery.
- Default profile when an enemy has no authored presentation resource.

### Juggernaut

- Slow, weighty rotation.
- Strong forward falling pose.
- Low ground bounce.
- Longer landing recovery.
- Faster juggle-resistance buildup.

## Shared architecture

`AirbornePresentationProfile` stores visual poses and reaction rhythm multipliers. `AirbornePresentationController` layers whole-body rotation, stretch, squash, bounce, plunge, and landing poses onto an actor's `VisualRoot`.

The controller listens to the existing `AirborneReactionController` signals instead of replacing combat physics. Existing limb-level enemy animation can continue inside `VisualRoot`, while the presentation controller moves the complete silhouette.

`EnemyActor` and `CombatTrainingTarget` attach both airborne controllers automatically. Enemies without an explicit resource receive the Standard profile.

## Automated coverage

```text
scenes/tests/airborne_presentation_smoke_test.tscn
```

The smoke test checks profile ordering, launch rotation, plunge state, bounce pose, landing recovery, and restoration to the base visual transform.
