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

For a live test, use any weapon at Familiar rank or above. Dodge sideways, backward, and forward, then press each attack input during the dodge. The technique should follow the dodge direction and appear by name in combat debug data.
