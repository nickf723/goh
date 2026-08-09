# Spell Presentation Grammar v1

## Goal

Gameplay reports what a spell is doing. Presentation decides how that meaning is expressed through sound, haptics, light, VFX, and future animation/audio assets.

```text
gameplay event -> semantic spell phase -> Presentation Director -> sensory layers
```

Spell gameplay code should not hardcode shared sound IDs, camera kicks, or generic casting VFX when a lifecycle phase can express the same intent.

## Lifecycle phases

- `prepare`: magic is being gathered, aimed, charged, or readied.
- `release`: the prepared spell leaves Grace or commits to the world.
- `travel`: a projectile or traveling effect is in flight. Usually subtle.
- `manifest`: a summon, field, curse, plant, or other world state appears.
- `latch`: a tether, grapple, hook, or target-bound connection succeeds.
- `sustain`: an already-established effect remains active. Throttled by the Director.
- `resolve`: the spell produces an authored consequence such as a curse pulse or spirit pass.
- `handoff`: one delivery form becomes another autonomous form.
- `cancel`: preparation or an ongoing spell ends without its normal resolution.

## Elemental language

All sixteen elements have a presentation color and procedural audio accent:

Water, Earth, Fire, Air, Ice, Metal, Lightning, Poison, Life, Death, Body, Soul, Dreams, Sound, Space, and Time.

The procedural sounds are tuning placeholders. Authored audio can replace any cue later without changing spell gameplay code.

## Reference spells

### Firebolt

`prepare -> release -> travel -> impact`

Charged Firebolt owns a longer prepare phase. The impact system still owns material contact and enemy reaction weight.

### Plant Summon

`prepare/aim -> release -> manifest`

Plant configuration remains outside combat. The lifecycle system only presents the prepared cast.

### Vine Grapple

`prepare -> release -> latch -> sustain -> resolve/cancel`

The tether runtime owns latch and tension semantics because only it knows whether a valid connection actually happened.

### Death Hex

`prepare -> release -> travel -> manifest -> sustain -> resolve pulses`

The curse manifests before its deferred sustain cue so the presentation order matches the gameplay order.

### Wraith Pursuit

`prepare -> release -> travel -> handoff -> sustain -> resolve passes`

The projectile owns the handoff. The autonomous spirit begins its sustain presentation one deferred frame later.

## Layering rules

- Gameplay remains authoritative. Presentation never decides hits, targets, costs, status application, or success.
- WeaponController retains ownership of authored melee hit stop and major melee camera impact.
- Spell lifecycle presentation does not duplicate the material-aware impact system.
- Persistent/repeated phases are throttled to avoid sensory spam.
- Presentation telemetry stores names/data rather than live Node references.
- Temporary audio players use weak references and a live-player cap.
- Ground-targeted spells present preparation when targeting begins and manifestation only after a successful confirmation.

## Polish Studio

Open:

```text
res://scenes/levels/prototypes/prototype_polish_studio_v1.tscn
```

Controls added for presentation tuning:

- `F5`: cycle material/reaction impact previews.
- `F6`: cycle reference spell lifecycle previews.
- `F8`: reset the studio.

Actual spells can also be cast freely in the studio with regenerating resources.
