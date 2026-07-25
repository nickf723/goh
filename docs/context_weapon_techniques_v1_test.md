# Context Weapon Techniques v1

Weapon techniques are permanent additions to Grace's move vocabulary. They are not equipped into slots and do not add new buttons. The resolver watches the player's current action context and converts an existing attack input into an unlocked technique.

## Dash Strike

Every weapon class unlocks its first Dash Strike at **Familiar mastery rank**.

1. Dodge in any direction.
2. Press Light or Heavy Attack before the dodge ends.
3. The dodge branches immediately into the weapon's class-specific technique.
4. The strike inherits the dodge direction and preserves the dodge cooldown.

Examples include Passing Cut for swords, Driving Thrust for lances, Meteor Rush for hammers, Comet Chain for chains, Pursuit Crack for whips, and Vaulting Sweep for staffs. All sixteen default weapon classes have individual damage, stance, range, and movement tuning.

The mastery description now names the technique and its trigger.


## Aerial set

Every weapon also gains three airborne techniques at Familiar mastery rank:

- **Aerial Sweep:** jump and press Light without directional movement. This produces a broad 360-degree defensive strike.
- **Aerial Pursuit:** jump, hold a movement direction, and press Light. This advances toward the attack direction; a successful hit briefly preserves height and pulls Grace toward the target.
- **Plunging Heavy:** jump and press Heavy. This commits Grace downward and arms a radial landing impact whose strength scales with falling speed.

Each of the sixteen classes has its own named set. Examples include Orbit Cut / Comet Slash / Falling Edge for swords, Needle Wheel / Skyline Thrust / Dragon Drop for lances, and Iron Orbit / Comet Cast / Anchorfall for chains.

All aerial attacks retain weapon mastery upgrades, elemental infusion, hit reactions, and existing combo payload behavior. Flight mode remains excluded so ordinary weapon inputs do not conflict with its traversal controls.

Grounded Heavy finishers at Familiar rank also receive vertical launch force. The resulting loop is:

```text
Grounded Heavy finisher → launch target → jump → Aerial Pursuit → height-preserving hit → Plunging Heavy → landing impact
```

Missing an aerial attack does not preserve height. This makes continued aerial pressure depend on connecting rather than allowing indefinite air movement.

## Context vocabulary

Weapon payloads now identify these contexts:

- `technique_dash`
- `context_combo` at the second attack onward
- `context_deep_combo` at the third attack onward
- `context_finisher` when an attack has no authored follow-up

These tags are extension points for future unlocks such as aerial attacks, sprint attacks, guard counters, perfect-dodge reprisals, low-health properties, charged finishers, and element-specific combo mutations. Multiple unlocked techniques can coexist because context determines which one is eligible.

## Test

Run:

```text
scenes/tests/context_weapon_technique_smoke_test.tscn
```

For a live test, use any weapon at Familiar rank or above:

1. Dodge sideways, backward, and forward, then press each attack input during the dodge.
2. Complete a grounded Heavy finisher and confirm the target receives upward launch force.
3. Jump without movement and press Light for Aerial Sweep.
4. Jump while holding movement and press Light for Aerial Pursuit; connect and confirm Grace briefly preserves height.
5. Jump and press Heavy for Plunging Heavy; land and confirm the radial elemental impact appears.

The active technique should appear by context ID in combat debug data.
