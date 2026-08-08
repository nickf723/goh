# Repeat v1

Repeat is a Time concentration spell that creates a friendly delayed copy of Grace's timeline.

## Concentration contract

```text
Element: Time
Mana reservation: 30% of maximum Mana
Base echo count: 1
Base delay: 1.0 second
Additional echo spacing: 0.42 seconds
Repeated weapon damage: 68%
Repeated stance pressure: 80%
```

Casting Repeat while it is inactive reserves 30% of Grace's maximum Mana and creates the echo. Casting Repeat again releases concentration and removes all Repeat echoes. Activating another concentration effect also releases Repeat through the shared concentration manager.

## Timeline replay

The controller records Grace once per physics frame. Each snapshot stores:

- Grace's world transform;
- the complete Grace visual root transform, including Grow/Shrink scale;
- articulated body, head, hands, shoulders, legs, face, hair, and sash pivots;
- the active Body form identifier.

The echo samples an older snapshot instead of independently simulating movement. This makes it reproduce the animation Grace actually performed rather than guessing from current input.

The echo has no collision and cannot hurt Grace. It is rendered as a translucent blue-violet time image.

## Weapon attacks

Repeat listens to Grace's ordinary weapon attack signal. A delayed attack event is created for every active echo. When that echo reaches the attack moment, Repeat performs a fresh overlap query at the echo's location and delivers a `DamagePayload` to valid receivers.

Repeated weapon payloads receive:

```text
time
repeat
echo
delayed_copy
```

If Grace was Grown or Shrunk when the original attack began, the repeated payload also records that Body-form tag and captures the form-adjusted weapon range and force.

This means the useful part is spatial, not merely cosmetic: Grace can move away while her old position attacks again one second later.

## Upgrade architecture

`RepeatEchoController.echo_count` already supports multiple time followers. Every additional echo uses the same timeline with an additional delay offset.

The controller also exposes `register_repeat_source()`. v1 records Grace as the authoritative timeline, but the public source registry is intentionally present for a future Soul duplication spell. A Soul double can register itself as a Repeat source without changing the spell-facing API.

That future composition can become:

```text
Grace
Soul Double
    ×
Repeat Echo 1
Repeat Echo 2
Repeat Echo 3
```

The eventual multi-source implementation should give each registered source its own history lane and echo set.

## Spell replay boundary

v1 repeats movement, articulated animation, and weapon attacks. It does not re-cast arbitrary spells yet. Replaying arbitrary abilities needs an action relay rather than blindly invoking `AbilityDefinition` again because self-targeted transformations, concentration spells, channels, summons, and world-authority spells have very different ownership rules.

A later Repeat upgrade can add a safe replay policy such as:

```text
Projectile / burst spell → duplicate from echo position
Movement spell           → visual replay only unless explicitly supported
Transformation           → copy recorded form visually, do not recast
Concentration            → never recursively recast
Summon                    → upgrade-gated duplication
```

## Grow/Shrink visual fix

Body-form collision was already correct, but Grace's presentation stack could reclaim the visual root after the transform and return the model to normal size.

Runtime Body casting now installs `PlayerBodyFormControllerVisualAuthority`. It runs at process priority 80, after Grace's articulated visual rig, and reapplies the authoritative Body-form root scale and grounded visual position every transformed frame.

This deliberately separates responsibilities:

```text
Animation rig owns pose
Body form owns scale
Physics owns collision
```

Grow and Shrink therefore remain visually matched to their working collision capsules instead of flashing at the correct size and snapping back.

## Focused test

1. Cast Grow and keep moving for several seconds. Grace should remain visibly large.
2. Cast Shrink and keep moving/dodging. Grace should remain visibly small.
3. Open Time in Focus and cast Repeat (`R↺`).
4. Run in a curved path. The translucent echo should trace that same route about one second behind.
5. Attack a dummy, then move away. The echo should attack again from the old location one second later.
6. Cast Grow while Repeat is active. The echo should replay the recorded large visual state when it reaches that portion of the timeline.
7. Cast Repeat again. The echo should vanish and the reserved Mana ceiling should be restored.
