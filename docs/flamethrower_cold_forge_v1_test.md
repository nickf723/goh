# Flamethrower and the Cold Forge v1

## Purpose

Validate the first sustained-casting spell and prove that its puzzle identity comes from continuous thermal energy rather than a hard-coded Flamethrower requirement.

Firebolt and Flamethrower both deliver Fire, but they occupy different roles:

```text
Firebolt      = one discrete heat impulse at long range
Flamethrower  = short-range heat flux maintained while Cast is held
```

## Launch

Run:

```text
res://scenes/levels/prototypes/prototype_cold_forge_spell_trial_v1.tscn
```

The scene equips Flamethrower automatically. It restores Mana on entry and regenerates Mana at 2 points per second. Flamethrower drains Mana at 3 points per second, so the Mana bar should still fall while channeling and recover between attempts.

## Controls

- Move and camera: normal controls
- Focus spell library: normal Focus input
- Start and sustain Flamethrower: hold Cast
- End Flamethrower: release Cast
- Reset the complete trial: F8 / RESET

Grace may move and aim while channeling. Attacking, dodging, guarding, interacting, changing spells, entering Focus, being staggered, or running out of Mana ends the channel.

## Spell behavior

1. Hold Cast in open space.
2. Confirm a short cone of layered red-orange and yellow flame follows Grace's aim.
3. Confirm Mana drains in whole points over time rather than paying a fixed cost on activation.
4. Release Cast and confirm the stream disappears immediately.
5. Tap Cast several times for very short bursts. Fractional Mana cost should accumulate between taps, preventing free micro-bursts.
6. Empty the Mana bar and confirm the stream stops automatically.
7. Confirm Mana begins regenerating after the stream ends.

The stream applies continuous thermal energy every frame. Combat damage, Burning, and elemental reactions are delivered on controlled quarter-second ticks so damage and reaction frequency do not depend on frame rate.

## Room I: Fading Lock

The frozen seal begins near `-35 °C`, continuously exchanges heat with the cold room, and requires approximately `150 °C` to be maintained for `1.25 seconds`.

1. Equip Firebolt and strike the seal once.
2. Confirm its temperature rises briefly, then falls back toward ambient.
3. Confirm the inner gate remains closed.
4. Re-equip Flamethrower.
5. Move close to the seal and hold Cast on it.
6. Confirm the displayed temperature climbs continuously.
7. When the threshold is reached, keep the stream on the seal through the full hold interval.
8. Confirm the inner gate opens and remains open after the seal cools.

The target does not inspect the spell ID. Any future heat source capable of overcoming its cooling and maintaining the threshold can solve it.

## Room II: Boiler Lift

The boiler core rides on the elevator platform. Its real temperature is forwarded as a numeric mechanism value:

```text
-35 °C  → 0% lift height
150 °C  → 100% lift height
```

1. Step onto the platform.
2. Aim at the boiler mounted on the platform and hold Flamethrower.
3. Confirm the boiler temperature and lift percentage rise together.
4. Keep aiming while the platform moves.
5. Stop casting partway up and confirm cooling lowers the platform.
6. Heat it again and step onto the upper landing.
7. Confirm the mastery pad completes the trial and records `cold_forge_spell_trial_complete`.

This room proves that sustained heat can drive proportional machinery rather than only activate a Boolean lock.

## Combat and interruption regression

In another combat-capable scene, select Flamethrower and verify:

- enemies in the cone receive repeated small Fire payloads;
- Burning and Fire reactions occur at a stable tick rate;
- multiple nearby targets may be swept by the cone;
- walls clamp the stream and prevent heating objects behind them;
- Guard, Dodge, weapon attacks, spell changes, stagger, death, and Focus cancel the channel cleanly;
- movement remains available while channeling;
- no permanent `is_casting` lock remains after interruption.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/flamethrower_cold_forge_smoke_test.tscn
```

The regression covers:

- Flamethrower presence in Grace's spell library;
- zero fixed Mana cost and channel delivery identity;
- persistent action-state casting;
- continuous Mana drain;
- fractional cost across short bursts;
- Firebolt heat followed by ambient cooling;
- failure of one Firebolt to satisfy the sustained lock;
- Flamethrower overcoming active cooling;
- hold-time completion and gate activation;
- thermal value mapping to elevator height;
- mastery completion and reset behavior.

## Known limitations

- The flame is a procedural cone rather than a final particle, distortion, smoke, and lighting stack.
- Cone contact uses several overlapping sphere samples behind an occluding center ray rather than a custom cone collision primitive.
- Combat payloads affect targets on fixed ticks, while heat is continuous.
- The first trial contains the Fading Lock and Boiler Lift. The Split Furnace and Frostbound Custodian remain candidates for the next expansion after channel feel and thermal tuning are proven.
- Final audio, controller haptics, animation, camera recoil, aim slowdown, accessibility telegraphs, and balance are not represented.
