# Weapon Combat Framework + Three-Class Arena v0.6 QA

## Goal

Verify that Grace now has a reusable, readable Light/Heavy combo grammar and that Sword, Hammer, and Spear feel mechanically distinct while continuing to use the existing payload/receiver/reaction architecture.

The framework should feel like:

```text
Light → Light → Light → Light
   ↘ Heavy finisher at each step
```

The test is not asking whether the transform-driven prototype animations are final. It is asking whether the timing, branches, geometry, impact, movement, cancel rules, and class identities form a strong combat foundation.

## Branch and scene

Use:

```powershell
git fetch origin
git switch agent/weapon-combat-arena-v0-6
git pull
```

Run:

```text
scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn
```

Controls:

```text
J or left mouse       Light attack
K                     Heavy attack
Right shoulder / R1   Heavy attack
Q or right trigger    Cast equipped spell
C or controller A     Dodge
T or right-stick click Lock on
F8 in editor          Reset arena
E                     Interact with racks / reset console
```

## Expected room layout

The arena should contain:

- Grace near the front wall;
- Sword, Hammer, and Spear racks on a raised front dais;
- a violet reset console to the left;
- three colored combat lanes;
- three stationary force-aware training totems;
- Goblin and Gremlin live-combat spawns at the rear;
- a combat HUD in the upper-left;
- no invisible geometry inside the playable floor.

## Combat HUD

The custom HUD should update during every attack and display:

- equipped weapon and class;
- current attack name;
- startup, active, recovery, or idle phase;
- buffered input;
- current combo chain;
- remaining combo time;
- spell-cancel availability;
- dodge-cancel availability.

The HUD must reflect the runtime state rather than merely showing instructions.

## Basic input-buffer test

Stand away from all targets and equip the Practice Sword.

1. Tap Light once.
2. During the attack, tap Light once more.
3. Confirm the second attack begins after the first completes rather than firing immediately or being lost.
4. Repeat through all four Light attacks.
5. Deliberately wait until the combo timer expires.
6. Press Light again and confirm the chain restarts at Opening Cut.
7. Press buttons rapidly enough to place one input in the buffer.
8. Confirm one press causes one follow-up. No duplicate attack should occur.

Expected Sword Light chain:

```text
Opening Cut
→ Returning Cut
→ Rising Cut
→ Circular Cut
```

## Sword branch test

Reset between sequences when useful.

Confirm these branches:

```text
Heavy                       → Guardbreaker
Light, Heavy                → Rising Break
Light, Light, Heavy         → Crowd Cleave
Light, Light, Light, Heavy  → Driving Thrust
Light ×4, Heavy             → Orbit Finisher
```

Judge each branch by geometry and intent:

- Guardbreaker should be narrow, committed, and stance-focused.
- Rising Break should add upward force.
- Crowd Cleave should cover a broad group.
- Driving Thrust should move Grace farther forward and remain narrow.
- Orbit Finisher should cover nearly all directions and feel like the strongest Sword ending.

Confirm Light attacks use blue-white trails while Heavy attacks use warmer gold trails.

## Sword cancel test

The Sword’s Light attacks should permit late spell and dodge cancels.

For several Light attacks:

1. Press cast or dodge during startup while the HUD says `closed`.
2. Confirm the action does not interrupt the attack.
3. Repeat late in the attack when the HUD says `OPEN`.
4. Confirm Grace exits the weapon attack into the requested spell or dodge.
5. Confirm the combo runner returns to idle and does not later release a ghost hit.

Sword Heavy attacks should be more committed. Their permitted dodge window opens later, and they should not permit spell cancellation.

## Hammer identity test

Equip the Training Hammer.

Expected Light chain:

```text
Weighted Sweep
→ Backhand Crush
→ Falling Weight
```

Heavy branches:

```text
Heavy                → Groundbreaker
Light, Heavy         → Anvil Lift
Light ×2, Heavy      → Quake Sweep
Light ×3, Heavy      → Cathedral Bell
```

Confirm:

- startup and recovery are clearly slower than Sword;
- attacks cover broader areas than Spear;
- stance damage is visibly stronger on the totem HUD;
- knockback is stronger than Sword and Spear;
- Heavy attacks remain committed with both cancel indicators closed;
- Heavy payloads carry force and can participate in Frozen → Shatter once the reaction branch is present;
- Cathedral Bell feels like the largest commitment and impact in this pass.

The Hammer should not feel like a Sword with orange paint.

## Spear identity test

Equip the Training Spear.

Expected Light chain:

```text
Quick Jab
→ Passing Thrust
→ Clearing Arc
```

Heavy branches:

```text
Heavy                → Brace Pierce
Light, Heavy         → Shaft Sweep
Light ×2, Heavy      → Driving Skewer
Light ×3, Heavy      → Reaping Return
```

Confirm:

- Quick Jab and Passing Thrust reach targets that Sword cannot reach from the same distance;
- thrusts remain narrow and do not casually hit targets far to the side;
- Grace advances farther during Spear thrusts;
- Clearing Arc and the sweep finishers provide deliberate crowd coverage;
- Light attacks feel faster than Hammer;
- late spell and dodge cancels open during Spear Light attacks;
- Driving Skewer is the longest advancing attack in the current slice.

The Spear should reward spacing and alignment rather than functioning as a wide broom.

## Collision-respecting motion

Test Driving Thrust, Brace Pierce, Driving Skewer, and other advancing moves near:

- the outer walls;
- weapon racks;
- the reset console;
- training targets.

Confirm:

- Grace does not teleport through walls;
- Grace does not pass through solid props;
- movement ends naturally when collision blocks it;
- no attack launches Grace upward or below the floor;
- a dodge cleanly overrides remaining combat movement when its cancel window is open.

## Hit geometry and debug wedges

Each attack should briefly display a translucent debug volume:

- blue for Light;
- orange for Heavy.

Compare the wedge with actual hits:

- Sword should be medium-range and medium-width;
- Hammer should be broad and forceful;
- Spear thrusts should be long and narrow;
- sweep attacks should visibly widen their coverage;
- a target outside the displayed cone should not be hit;
- one attack should damage each target at most once.

The wedge is a development aid and not a release visual.

## Training totem behavior

Confirm each totem:

- appears in lock-on selection;
- shows health and stance feedback through existing receivers;
- can be staggered and knocked back;
- responds to launch force;
- does not vanish when depleted;
- resets to its original location, health, stance, statuses, and force state.

Use the totems to compare damage and stance pressure without enemy movement muddying the result.

## Live enemy test

Fight the rear Goblin and Gremlin with all three weapons.

Confirm:

- both retain their existing AI and attack behavior;
- lock-on and target switching still work;
- weapon attacks use the standard receiver stack;
- knockback/status feedback remains readable on the authored enemy shells;
- wide attacks can hit both enemies when positioned correctly;
- narrow Spear thrusts do not hit both unless they are aligned;
- defeating enemies does not corrupt the combo state;
- resetting the arena respawns both enemies at their markers.

## Reset test

Use the violet console, then repeat with editor F8.

Confirm reset:

- returns Grace to the starting position;
- clears action locks and combat movement;
- clears lock-on;
- restores Practice Sword;
- clears the combo chain and queued input;
- refills health, stamina, mana, stance, and usable focus;
- restores all training totems;
- respawns Goblin and Gremlin;
- leaves weapon racks usable.

## Spell compatibility

Cast spells before, during permitted cancel windows, and after weapon combos.

Confirm:

- normal casting remains unchanged while idle;
- casting cannot interrupt an attack while its spell-cancel indicator is closed;
- a permitted late cancel ends the weapon attack cleanly;
- no queued weapon strike releases after the spell;
- weapon payloads remain compatible with elemental reaction tags;
- spell selection and Focus menu behavior remain functional.

## Church Trial regression

Run:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Confirm:

- Practice Sword now uses its combo moveset;
- Light attacks still hit enemies and interactables reliably;
- Heavy attacks do not bypass gates or progression logic;
- spells, elemental lock, Sound bridge, save bed, boss, reward, inventory, and exit remain functional;
- Goblin and Gremlin AI and visuals remain unchanged;
- the Animated Armor remains completable with the new weapon controller.

## Automated coverage

CI should pass:

```text
Validate custom agent profiles
Import project headlessly
Start project headlessly
Start Church Trial headlessly
Start Elemental Reaction Lab headlessly
Validate elemental reaction recipes
Start Weapon Combat Arena headlessly
Validate weapon moveset graphs
Export Windows release
Upload Windows artifact
```

The graph test verifies:

- all three movesets contain valid unique attack IDs;
- every branch points to an existing attack;
- Sword has all four Heavy branch positions;
- Hammer entries carry force and its neutral Heavy is fully committed;
- Spear outranges and is narrower than Sword;
- all tested attacks produce standard melee `DamagePayload` objects;
- expected `light`, `heavy`, `force`, `blunt`, and `pierce` tags survive payload construction.

## Creative review

The final authority is feel, not the green workflow.

Judge:

1. Does buffered input feel responsive rather than delayed or overeager?
2. Can you intentionally choose each Heavy branch?
3. Do startup, impact, and recovery communicate attack weight?
4. Are Sword, Hammer, and Spear instantly distinguishable without reading the HUD?
5. Do the cancel windows create useful decisions?
6. Does Grace remain controllable during crowded combat?
7. Is Warriors-style branching a strong fit for the larger spell-and-reaction sandbox?

## Known limitations

- Weapon poses are transform-driven procedural proxies, not skeletal animations.
- Hit detection uses one sphere query plus a directional cone at the active frame.
- There is no block, parry, aerial combat, dual wielding, execution, skill tree, loot rarity, or final stamina balance.
- Only Sword, Hammer, and Spear are included.
- Camera impulse and authored audio are deferred until timing and class identities are approved.
