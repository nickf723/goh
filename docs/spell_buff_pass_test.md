# Spell Buff Pass v1 Test

## Goal

Make Grace's current prototype spells feel more useful, more distinct, and easier to test against the new enemy pressure behavior.

This is a tuning/content pass, not a full spell architecture pass.

## What changed

### Global projectile feel

Generic projectiles are faster and slightly shorter-lived:

- `speed`: `14.0` -> `18.0`
- `max_lifetime`: `3.0` -> `2.6`

This should make Arcane Spark, Firebolt, Ice Lance, and Lightning Spark feel snappier, especially against Gremlins.

### Arcane Spark

- More stance pressure.
- Light knockback.
- Keeps the `force` tag so it can still shatter frozen targets.

### Firebolt

- Higher direct damage.
- Applies a short burning status.
- Better identity as the simple damage spell.

### Ice Lance

- Stronger stance damage.
- Stronger chill control.
- Better identity as a setup/control projectile.

### Lightning Spark

- Adds a very short stun.
- Better identity as a quick interrupt/control projectile.
- Still pairs with wet targets through existing reactions.

### Sound Pulse

- Larger reveal radius.
- Longer reveal duration.
- Adds an optional echo status rider to `DetectionPayload`.
- Sound Pulse now briefly staggers enemies caught in the pulse while still revealing hidden objects.

### Fire Field

- Burning lasts longer.
- Burning ticks harder.
- Adds a little stance pressure.

### Poison Cloud

- Poison lasts longer.
- Poison ticks slightly harder.

### Wind Gust

- More stance pressure.
- Stronger knockback.
- Better control identity.

## How to test

1. Pull branch `agent/spell-buff-pass-v1`.
2. Run the usual dev scene.
3. Spawn `Goblin Duel`, `Gremlin Duel`, `Zombie Duel`, and `Mixed Wave`.
4. Try each spell against each enemy type.

## Expected feel

- Projectiles should be easier to land.
- Firebolt should feel like reliable damage.
- Ice Lance should noticeably slow/control enemies.
- Lightning Spark should briefly interrupt enemies.
- Sound Pulse should still reveal hidden objects and now briefly stagger nearby enemies.
- Fire Field and Poison Cloud should feel more worth setting up.
- Wind Gust should shove enemies with more authority.

## Regression checks

- Lock-on casting still aims projectiles correctly.
- Spell menu and quick-cast still work.
- Status icons still appear over enemies.
- Fire Field + Poison Cloud still triggers Toxic Ignition.
- Wind Gust + Fire Field still triggers Fanned Flames.
- Wind Gust + Poison Cloud still triggers Cloud Spread.

## Known risks

- Sound Pulse now affects enemies, so it may be stronger than intended.
- Lightning Spark's direct stun is intentionally short, but may still interrupt too much.
- Faster projectiles may make some projectiles feel less dodgeable later. Good for prototype feel, tunable later.
