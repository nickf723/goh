# Ruvia Fire Specialist Mechanics v1

## Purpose

Ruvia's Divine Incarnation now connects three previously separate identities:

```text
Fire authority
      +
Ember Halberd combat
      +
Fire spellcasting
      =
One continuous specialist kit
```

Grace remains the stable health, camera, progression, collision, and world-position anchor. Ruvia replaces the avatar's elemental relationship, weapon language, spell loadout, movement identity, and presentation without spawning a second player body.

## Elemental Authority

The reusable authority data contract is:

```text
scripts/player/elemental_authority_profile.gd
data/avatars/ruvia_fire_authority_profile.tres
```

A profile can define:

- matching-element damage and stance multipliers;
- blocked statuses;
- matching-hazard traversal;
- spell mana-cost changes;
- spell damage and stance multipliers;
- status duration and strength multipliers;
- projectile-speed changes;
- field radius and lifetime changes;
- weapon-spell weave timing;
- owned-field flare behavior;
- elemental wake behavior.

Ruvia's current Fire Authority grants:

```text
Matching Fire damage:       0%
Matching Fire stance harm:  0%
Burning:                    blocked
Fire hazards:               traversable
Fire spell damage:          130%
Fire spell stance:          120%
Burning duration:           135%
Burning strength:           125%
Fire projectile speed:      112%
Fire Field radius:          +0.45
Fire Field lifetime:        +1.0s
```

This is elemental specialization, not universal invulnerability. Ice, Poison, weapon damage, and other unmatched threats continue to affect Ruvia normally.

## Stable-avatar integration

The shared player installs:

```text
Player/ElementalAuthorityController
Player/StatusReceiver
```

`PlayableAvatarDefinition` now includes an optional `elemental_authority_profile`. Divine Incarnation definitions require one whose element matches the avatar's element.

The elemental avatar-manager layer captures, applies, validates, restores, and watchdog-checks the authority profile in the same transaction as movement, weapon, spells, and wire presentation.

On dismissal, Grace receives the authority profile captured before incarnation, which is currently `null`. Fire therefore becomes dangerous to Grace again immediately after Ruvia leaves.

## Matching-element defense

Incoming player-facing damage continues through `PlayerDefenseController`. Its elemental layer asks the active authority to resolve the payload before guard, stance, hit reaction, or health damage.

When Ruvia receives Fire:

1. Fire damage becomes zero.
2. Fire stance damage becomes zero.
3. The outcome is reported as `elemental_authority`.
4. No hit reaction or guard cost is applied.
5. The same Player health pool remains unchanged.

The player Status Receiver also refuses Burning while Fire Authority is active. Existing `StatusSurface` and `FireField` actors therefore recognize Ruvia as traversable rather than repeatedly reapplying a status she cannot possess.

## Halberd conduit casting

The Ember Halberd runtime rig now exposes a spell origin at its blade tip and a ground-channel origin at its butt cap.

Firebolt:

```text
Halberd spear tip
       ↓
Authority-enhanced payload
       ↓
Faster Fire projectile
```

Fire Field:

```text
Halberd ground plant
       ↓
Owned Fire Field
       ↓
Expanded radius and lifetime
```

The authority controller is a normal player ability channel. `AbilityCaster` still owns the selected spell and input. It offers the cast to direct player child components before using the generic scene-instantiation path. Ruvia's controller claims only matching Firebolt and Fire Field casts. Grace and unrelated abilities keep their existing paths.

## Two-handed casting

Ruvia no longer drops into Grace's generic one-hand spell pose.

The authority controller exposes a cast-pose sample containing:

- torso and head intent;
- rear-arm drive;
- guide-arm control;
- right-hand path;
- halberd-local rotation and translation;
- support-grip position;
- support-hand lock strength.

`GraceElementalAuthorityMotionVisual` applies the body pose. `PlayerWeaponControlAnimatorAuthority` then poses the weapon and locks the guide hand to the live shaft in the same order used by Ruvia's halberd attacks.

The procedural Ember Halberd raises its blade emission while it is acting as a Fire conduit.

## Owned Fire Fields

Authority-created fields record:

```text
owner actor
owner avatar id
authority profile
field kind
authority bonuses
```

Current field kinds are:

- `authority_field` for an ordinary Ruvia Fire Field;
- `haft_field` for the Haft Check weave;
- `scorching_thrust_wake` for short-lived wake segments.

Owned fields expose containment checks and an authority-flare action. Ordinary environmental Fire Fields remain unowned and retain their established reaction behavior.

## Contextual weapon-spell weaving

### Blade-Tip Firebolt

During the late cancel window of **Cinder Sweep** or **Backdraft Return**, Firebolt resolves as:

```text
blade_tip_firebolt
```

It uses Ruvia's quick weave lock, preserves the committed attack heading, cancels the weapon recovery cleanly, and launches from the halberd tip.

The same weave remains available for a short grace window immediately after either attack completes.

### Haft Field Plant

Fire Field cast from **Haft Check** resolves as:

```text
haft_field_plant
```

The field appears close to Ruvia rather than at ordinary field-cast distance. This converts her close-range spacing tool into a way to reclaim the halberd's preferred distance.

### Ember Wheel Field Flare

When **Ember Wheel** reaches its active phase, nearby owned Fire Fields gain:

- additional radius;
- additional remaining lifetime;
- stronger Burning while flared.

The weapon finisher and the existing field remain separate systems. The form asks the fields to flare rather than spawning a disconnected cinematic explosion.

### Scorching Thrust Wake

If **Scorching Thrust** begins while Ruvia stands inside one of her owned fields, its active travel leaves a short sequence of compact Fire Fields behind her.

Wake segments:

- use reduced field damage;
- have smaller radius;
- expire quickly;
- remain owned by Ruvia;
- can Burn enemies crossing the thrust path.

### Solar Descent Spread

When **Solar Descent** connects, its primary targets receive the finisher's established stronger Burning. Nearby enemies outside the primary target list receive a shorter, weaker Burning status.

This makes the finisher feel divine through systemic propagation rather than an unrelated cutscene attack.

## No Heat meter yet

v1 introduces no Heat bar, Divine Art meter, or additional resource loop.

Ruvia still uses the shared Mana, Stamina, Focus, stance, and action-state contracts. Her specialist identity comes from authority, ownership, contextual timing, positioning, and the established Burning system.

## Showcase

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

Press `F9` to incarnate Ruvia. The western Fire-weaving bay contains:

- an owned-field marker;
- four Scorching Thrust wake markers;
- reminders for blade-tip Firebolt and Haft Field Plant;
- HUD rows for authority, fields, weave windows, wake segments, field flares, negated hits, and conduit state.

Suggested manual circuit:

1. Let Grace touch an ordinary Fire hazard, then compare after pressing `F9`.
2. As Ruvia, stand in Fire and confirm no health, stance, hit reaction, or Burning appears.
3. Cast Firebolt from rest and watch the projectile leave the halberd blade.
4. Cast Fire Field and inspect the larger owned field.
5. Use Cinder Sweep, wait for late recovery, then cast Firebolt.
6. Repeat after Backdraft Return.
7. Use Haft Check, then cast Fire Field. The field should plant close to Ruvia.
8. Use Ember Wheel beside an owned field. The field should visibly swell.
9. Stand inside an owned field and perform Scorching Thrust. A short burning wake should remain behind the lunge.
10. Use Solar Descent near grouped targets and inspect Burning spread.
11. Press `F9` to return to Grace and confirm Fire vulnerability and ordinary spell casting return.

## Automated validation

Run in Godot:

```text
scenes/tests/ruvia_fire_specialist_smoke_test.tscn
```

Expected marker:

```text
RUVIA_FIRE_SPECIALIST_SMOKE_TEST: PASS
```

The regression checks:

- Grace's baseline Fire vulnerability;
- installation and restoration of Ruvia's authority profile;
- Fire damage, stance, hazard, and Burning immunity;
- preservation of vulnerability to unmatched elements;
- enhanced Firebolt payload, speed, and halberd-tip origin;
- two-handed halberd casting and finite wire poses;
- owned Fire Field metadata, radius, and lifetime;
- Cinder Sweep Firebolt weaving;
- Haft Check Fire Field planting;
- Ember Wheel owned-field flare;
- Scorching Thrust wake generation;
- Solar Descent Burning spread;
- safe dismissal to Grace's ordinary elemental behavior.

## Deliberate boundaries

- Spell release is still immediate at input; fully authored anticipation and release frames remain future animation work.
- Firebolt and Fire Field are the complete current registered Fire prototype set, not Ruvia's final spell library.
- Authority applies to player-facing defense and status surfaces; every bespoke future hazard must still route through those shared contracts.
- Fire trails, impact VFX, sound, rumble, and production character animation remain provisional.
- Field ownership is runtime-only and does not persist across scene changes.
- No autonomous Ruvia AI, manifestation meter, Divine Art, patron dialogue, or transformation cinematic is included.
