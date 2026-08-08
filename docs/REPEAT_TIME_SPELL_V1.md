# Repeat v2: timeline reenactment

Repeat is a Time concentration spell that reserves 30% of Grace's maximum Mana and creates a delayed echo of her timeline.

## Core rule

Repeat does **not** run a second simulation of the original action. It records what actually happened and reenacts that timeline one second later.

```text
Original event
    ↓ record motion / state / timing
One second later
    ↓
Temporal reenactment
```

The replay may affect new targets that now occupy the prerecorded route, but those new contacts never alter the remembered motion.

Example:

```text
Grace launches Boulder A
Boulder A hits Enemy A
Enemy A is knocked away
Boulder A deflects left and continues

one second later...

Boulder B follows the exact remembered path
It visibly performs the same left deflection
Enemy A is gone, so that remembered deflection has no new cause
Enemy B walks into the remembered path
Boulder B can damage Enemy B
Boulder B still continues along the original path
```

This is intentionally different from the planned Soul Duplicate spell.

```text
REPEAT
prerecorded timeline authority
same path, same timing, delayed
new contacts cannot redirect the memory

SOUL DUPLICATE
live second actor
same action at the same time
physics and world state resolve independently
```

## Grace timeline

Repeat records Grace every physics frame, including:

- world transform;
- articulated body pose;
- Grow/Shrink visual scale;
- traversal produced by Surf, Flash, Flight, jumps, dodges, and ordinary movement.

This means transformations and traversal do not need to be re-cast. The echo simply reaches the same recorded state one second later.

## Weapon attacks

Weapon attacks replay at the delayed Grace position. The repeated attack receives the original Body-form-adjusted damage, stance, reach, and force identity, then evaluates targets occupying that historical attack space at replay time.

## Spell semantics

`SpellCloneSemantics` gives every ability two independent modes:

```text
repeat_mode
    timeline_trajectory
    timeline_recast
    timeline_source_state
    timeline_channel
    world_state_noop
    suppress

duplicate_mode
    live_recast
    live_source_state
    world_state_noop
    suppress
```

### Timeline trajectory

Used for effects whose actual world root travels with the spell, such as:

- Firebolt
- Ice Lance
- Boulder
- Curling Puck
- similar moving-root projectiles

Repeat records the original effect's world transform every physics frame. A kinematic temporal shell later follows those exact transforms. It performs swept overlap checks for new targets but cannot be redirected by those contacts.

Multi-instance spells whose individual pieces move inside a stationary controller are handled differently. Metal Needle, for example, owns nine needles inside one MultiMesh, so recording the controller root would record no useful motion. Its deterministic fan is instead recreated from the delayed echo. A future per-instance timeline recorder can promote spells like this to exact needle-by-needle memory if needed.

### Timeline recast

Used for deterministic bursts and fields whose meaningful geometry can be recreated from the delayed Grace echo, including:

- Metal Needle
- Lightning Spark
- Wave
- Lightning Bolt
- Wind Well
- Contagion Cloud
- Asteroid Belt
- Echolocation
- similar instant or deterministic effects

These are recreated around the delayed echo using the recorded cast intent.

### Timeline channels

Water Jet and Flamethrower record their actual stream origin, aim direction, resolved length, and duration every physics frame. Their temporal streams later consume those recorded samples instead of reading current input.

Water Jet's temporal stream can damage, Wet, and push new targets occupying the recorded hose line. It does not reapply self-propulsion to Grace because the echo's movement timeline already contains the original launch.

Firewall records the actual authored `path_points`, surface normals, and phase progression. Its temporal Firewall redraws the same route and erupts on the same delayed schedule. New targets occupying the repeated flame wall can be damaged without changing the remembered path.

### Source-state replay

- Grow / Shrink: copied by Grace's recorded visual and collision-state timeline.
- Surf / Flash / Flight: copied by Grace's recorded traversal timeline.
- Bubble: activation is delayed, and its burst is scheduled for the same delayed moment the original Bubble popped.

### World-state no-op

Global weather does not stack or cancel itself:

```text
Rain
Snowfall
Thunderstorm
```

The echo reaches the cast moment and intentionally does nothing because the original world state already exists.

### Suppressed ownership

These remain intentionally blocked:

- Repeat recursively casting itself;
- Soul Grip;
- Metal Tether;
- persistent summons;
- recorded-object summons;
- artificer assemblies;
- deployed contraptions.

These actions create ownership relationships or persistent autonomous actors rather than a replayable spell event.

## Bubble timing

Repeat's Bubble is event-driven:

```text
Original Bubble activates at t = 0
Original Bubble absorbs a hit at t = 2.3

Echo Bubble activates at t = 1.0
Echo Bubble performs its burst at t = 3.3
```

The echo does not need the original attacker to still exist. The burst happens because that event belongs to the recorded timeline, then affects whatever valid bodies are near the delayed echo at that moment.

## Future Soul Duplicate

Soul Duplicate should consume the same semantics table but use `duplicate_mode`.

For most spells this means `live_recast`: a second Firebolt, Boulder, Water Jet, Firewall, Asteroid Belt, etc. happens simultaneously and owns an independent simulation.

Transformations and traversal use `live_source_state`, because the duplicate is a real controlled body that can Grow, Shrink, Surf, Flash, or Fly for itself.

Weather remains a world-state no-op, while summon/grab/object ownership remains suppressed unless explicitly upgraded later.

This creates the intended composition:

```text
Grace performs action now
Soul Grace performs a second live action now
Repeat Grace reenacts Grace one second later
Repeat Soul Grace can eventually reenact Soul Grace one second later
```

## Focused playtest

1. Cast Repeat and fire a projectile into a wall or target that changes its route.
2. Watch the temporal projectile follow the exact same recorded route one second later even if the original target moved.
3. Put another target into the temporal route and confirm it can be hit without redirecting the replay.
4. Cast Boulder into an enemy and inspect the remembered deflection carefully.
5. Hold Water Jet while sweeping the camera. The temporal jet should reproduce the same sweep one second later.
6. Do the same with Flamethrower.
7. Draw a bent Firewall. The temporal line should redraw and erupt on the same delayed route.
8. Cast Bubble and let it absorb a hit. The temporal Bubble should pop one second after the original pop.
9. Cast Asteroid Belt while moving. The belt should appear around the delayed echo and follow that echo's recorded Grace path.
10. Use Surf, Flash, Flight, Grow, or Shrink and confirm the delayed Grace reenacts those state changes without recursively casting them.
11. Fire Metal Needle and confirm the delayed echo recreates the same fan rather than trying to record a stationary MultiMesh root.
12. Cast Rain/Snowfall/Thunderstorm and confirm no duplicate world-state weather is created.
13. Release Repeat and confirm every pending timeline effect cleans up.
