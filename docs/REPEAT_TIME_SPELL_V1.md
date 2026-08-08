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

## Spell replay: copy the action, never the original result

Repeat now observes the actual ability scene Grace adds to the world. One second later, a clone-safe spell is instantiated again from the echo's historical position and recorded cast direction.

The important rule is:

```text
Original cast happens
        ↓
The world changes normally
        ↓
One second later Repeat performs a NEW cast
        ↓
That cast interacts with whatever exists now
```

Repeat never stores or reapplies the original spell's hit list.

Example:

```text
Grace casts Boulder at Enemy A
Boulder hits A, knocks A left, then veers left
        ↓ one second
Echo Boulder starts from old Grace's position
Enemy A is no longer in the lane
        ↓
Echo Boulder misses A
But Enemy B walks into the new lane
        ↓
Echo Boulder can hit B normally
```

This same rule applies to Firebolt, Ice Lance, Metal Needle, Curling Puck, Contagion Cloud, and every other approved clone-safe cast.

Replay roots are tagged with:

```text
clone_spell_replay = true
clone_spell_kind = repeat
clone_copies_original_result = false
clone_fresh_world_interaction = true
```

A lightweight blue-violet temporal tint is applied after the echoed spell finishes constructing its own visuals, making repeated spells readable without replacing their underlying elemental identity.

## Clone-safe policy

`SpellCloneReplayPolicy` is deliberately shared infrastructure rather than Repeat-specific logic. A future Soul duplicate can use the same rules.

Currently approved examples include:

```text
Firebolt
Ice Lance
Lightning Spark
Sound Pulse
Poison Cloud
Fire Field
Wind Gust
Earth Spike
Metal Needle
Life Thorn
Death Hex
Body Burst
Soul Thread
Dream Snare
Time Snare
Wave
Lightning Bolt
Wind Well
Contagion Cloud
Boulder
Curling Puck
Echolocation
Resonant Pulse
Gust
```

These casts are replayed as independent actions.

The following families are suppressed instead of copied:

```text
Concentration spells
Weather ownership
Body transformations
Self-teleports / traversal states
Self-defense states
Held channels
Firewall's drawn path
Grab / tether ownership
Summons and deployed persistent objects
```

Examples:

```text
Rain / Snowfall / Thunderstorm → echo does nothing
Repeat                         → cannot recursively Repeat
Grow / Shrink                  → echo uses recorded visual form, does not transform
Flight                         → no second concentration
Surf / Flash                   → movement is already represented by the delayed timeline
Bubble / Asteroid Belt         → original body owns the persistent self-state
Water Jet / Flamethrower       → blocked until channel duration is explicitly recorded
```

New ordinary projectile and instant spells default to replayable unless their roles or delivery type declare clone-unsafe ownership. New utility, summon, transformation, and movement spells default to suppressed until their semantics are reviewed.

## Shared Duplicate architecture

The policy and replay engine are named around **clones**, not Repeat, because the eventual Soul duplicate should use exactly the same contract.

A Soul double should therefore be able to say:

```text
SpellCloneReplayPolicy.get_policy(ability)
SpellCloneReplay.replay_cast(...)
```

and inherit the same rule: duplicate the action, not the previous outcome.

This allows future compositions like:

```text
Grace casts Firebolt
Soul Grace casts its own Firebolt
Repeat trails Grace with another Firebolt
Repeat trails Soul Grace with another Firebolt
```

Every projectile owns its own trajectory and collisions. No duplicate is handed a prerecorded target list.

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

1. Cast Repeat (`R↺`), then cast Firebolt. A blue-violet echo Firebolt should leave the historical Grace about one second later.
2. Move sideways immediately after the first Firebolt. The repeated Firebolt should still originate from the echo's old position.
3. Cast Boulder toward a moving enemy. The echoed Boulder should replay the launch, not the original hit result.
4. Put a different target into the echoed projectile's future path and confirm the echoed spell can hit it independently.
5. Test Curling Puck or Contagion Cloud and confirm their later world interactions belong to the echo instance.
6. Cast Grow while Repeat is active. The echo should replay the recorded large visual state when it reaches that portion of the timeline, but it should not cast Grow itself.
7. Inspect the policy for Rain, Snowfall, Thunderstorm, Flight, Repeat, Grow, Shrink, Surf, and Bubble. These should be suppressed rather than recursively or globally duplicated.
8. Cast Repeat again. Echoes and pending spell replay events should be cleaned up and reserved Mana restored.
