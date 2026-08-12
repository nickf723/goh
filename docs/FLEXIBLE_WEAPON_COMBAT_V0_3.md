# Grace of Humanity — Flexible Weapon Combat v0.3

## Purpose

This pass targets three playtest findings from the Arsenal Dojo:

1. Bow, Shuriken, and Boomerang could lose the target while Grace moved.
2. Whip and Chains behaved like a powerful endpoint attached to a visually unstable line.
3. Flail had orbit-themed numbers and visuals but no flexible-weapon physics.

Primary playtest scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

## Combat v2 controller

The dojo now uses:

```text
res://scenes/actors/player/player_combat_v2.tscn
```

Its WeaponController extends the existing SafeWeaponController rather than replacing the combat architecture.

### Live ranged aim

Bow, Shuriken, and Boomerang re-sample combat aim when their contact query executes.

Movement input no longer blends into the projectile heading. Grace should be able to strafe laterally while continuing to fire at the camera / soft-aim / lock-on target.

### Safe collider ancestry

Player weapon collision resolution now walks only upward from the actual collider.

A floor or wall can no longer reach the scene root and recursively nominate an unrelated sibling HitReceiver elsewhere in the room.

This also makes ranged obstruction meaningful: if a shot ray hits architecture, the architecture blocks the ray unless that collider or one of its ancestors is actually a payload receiver.

### Per-contact flexible payloads

Runtime weapon rigs may optionally provide:

```text
modify_payload_for_target(payload, target, attack)
```

This lets one flexible weapon swing give different contact authority to different targets based on which segment struck them.

## Whip v2

The Whip still uses authored tip intent, but the endpoint is no longer teleported directly to that intent each render frame.

Instead:

```text
authored tip target
→ velocity-limited physics drive
→ pinned FlexibleTether endpoint
→ damped Verlet line
```

The tether receives stronger damping and more constraint iterations.

Combat contact is sampled along the distal ~82% of the simulated line, including segment midpoints.

Contact strength combines:

- position along the whip;
- local segment speed;
- overall line speed;
- line straightness.

The tip remains strongest and is still responsible for the best crack behavior, but mid-line contact now deals a legitimate reduced hit instead of passing through enemies as decoration.

## Chains v2

Chains use the same stabilized endpoint principle with lower acceleration and a heavier response.

The entire simulated chain is sampled for contact. The weighted head remains strongest, but links can batter nearby targets during a broad orbit.

This is intended to create two simultaneous identities:

```text
chain body = space control / sweeping contact
weighted head = peak momentum / displacement
```

## Physical Flail

The Flail proxy now equips:

```text
res://scenes/weapons/flail_weapon_rig.tscn
```

It uses a short 9-segment simulated chain and a head-heavy endpoint.

The attack graph still supplies the desired orbit, but the head must physically chase that orbit through a slower constrained endpoint drive. It therefore lags direction changes, builds momentum, and settles rather than rotating as a rigid prop.

The Flail remains a proxy weapon. This pass tests whether flexible-head physics belongs in its final combat identity before permanent moveset and animation authoring.

## First manual test

### Ranged movement

Equip Bow, Shuriken, or Boomerang.

1. Stand at useful range from the center or range target.
2. Hold left/right movement.
3. Keep the camera or lock-on pointed at the target.
4. Fire Light and Heavy attacks while continuously strafing.

Pass if the shot continues to follow combat aim instead of bending toward movement direction.

### Architecture blocking

Place a wall or dojo boundary between Grace and a target, or fire into the arena wall with another target elsewhere in the scene.

Pass if the wall receives/stops the query and an unrelated target does not take damage.

### Whip

Test broad Light attacks, precision attacks, and wrap behavior.

Watch the whole line rather than only the tip.

Pass questions:

- Is the line visibly calmer?
- Can the middle/distal body make reduced contact?
- Does the tip still read as the dangerous crack zone?
- Does wrap remain understandable?

### Chains

Swing through clustered targets.

Pass questions:

- Can links contact a target before the weight reaches it?
- Does the head still feel noticeably heavier than the body?
- Does the line preserve a connected orbit rather than exploding into noisy oscillation?

### Flail

Equip the `FLAIL • PROXY • PHYSICS` pedestal.

Test repeated Lights, Heavy entries, changes of direction, whiffs, and target contact.

Pass questions:

- Does the head lag direction changes?
- Does momentum feel earned rather than scripted?
- Is the weapon controllably unruly rather than random?
- Does a whiff carry enough follow-through to sell the weight?

## Automated regression

```text
res://scenes/tests/flexible_weapon_combat_v2_smoke_test.tscn
```

The regression checks:

- the derived CombatWeaponControllerV2 is active in the dojo;
- strafing input does not change ranged combat aim;
- floor collision cannot resolve to a sibling combat target;
- Whip and Chain scenes use their v2 rigs;
- both lines expose whole-body contact sampling;
- stabilized tether damping is active;
- Flail uses a real short FlexibleTether and heavy endpoint;
- the Flail pedestal equips the physical runtime rig.

## Next likely combat pass

After playtesting this family, the highest-value broad combat problem remains defender presentation:

```text
contact
→ local flinch
→ stagger / launch pose
→ controlled displacement
→ damping
→ authored recovery
```

Flexible weapons should be tuned only enough to prove their identities before that shared contact-feel pass.
