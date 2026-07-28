# Divine Incarnation Avatar Proxy v0.1

## Purpose

Divine Incarnation lets Grace manifest a god and transfer player control to that god's combat identity.

The first implementation deliberately does **not** spawn a second player body or replace the shared `Player` node. Too many mature systems already depend on the stable player path, collision body, camera, lock-on target, health pool, objectives, interaction area, UI, recovery controller, and progression anchor.

Instead, v0.1 uses a stable avatar proxy:

```text
Grace's persistent Player anchor
              ↓
      PlayableAvatarDefinition
              ↓
movement profiles + weapon + spells + presentation
              ↓
      controlled divine identity
```

The god changes what the player body can do and how it reads, while the underlying world anchor remains continuous.

## Stable-anchor contract

During incarnation, the following remain attached to the same `CharacterBody3D` instance:

- world transform;
- velocity;
- collision shape;
- camera and spring arm;
- lock-on target;
- shared health;
- stamina, mana, stance, focus, and progression state;
- inventory and equipment ownership;
- objective state;
- interaction and recovery systems;
- scene ownership and checkpoint identity.

The current avatar may replace:

- ground-motion profile;
- vertical-motion profile;
- dodge-motion profile;
- combat-footwork profile;
- equipped combat weapon;
- spell loadout;
- selected starting spell;
- diagnostic wire presentation.

This prevents Divine Incarnation from becoming a hidden extra life, a duplicate progression character, or a second camera competing for ownership of the scene.

## PlayableAvatarDefinition

```text
scripts/player/playable_avatar_definition.gd
```

Each avatar definition contains:

```text
identity
avatar kind
element and patron
availability and required unlock
manifestation duration
weapon definition
ability loadout
four movement profiles
wire palette
shared-anchor preservation rules
```

Current definitions:

```text
data/avatars/grace_avatar_definition.tres
data/avatars/ruvia_incarnation_prototype.tres
```

Grace is the mortal anchor definition. Ruvia is the first Divine Incarnation prototype.

## PlayerAvatarManager

```text
scripts/player/player_avatar_manager.gd
```

The shared player installs:

```text
Player/AvatarManager
```

The manager owns the transition transaction.

### Incarnation sequence

1. Validate the avatar definition.
2. Check the progression gate unless the call is explicitly debug-forced.
3. Capture Grace's current configuration, not merely her startup equipment.
4. Capture the stable runtime anchor.
5. Quiesce targeting, charging, attacks, dodges, footwork, and action locks.
6. Apply the avatar's movement profiles, weapon, spells, and presentation.
7. Restore transform, velocity, target, camera, health, and objective state.
8. Validate the live contract.
9. Commit the new active avatar only when every required layer agrees.

### Dismissal sequence

1. Capture the avatar's current runtime anchor.
2. Quiesce active actions.
3. Restore the mortal configuration captured immediately before incarnation.
4. Restore the current world transform, velocity, target, camera, health, and objective.
5. Return active-avatar metadata to Grace.

Grace therefore returns where the god currently stands, not where Grace began the incarnation.

## Transaction safety

Avatar swaps are atomic from the manager's perspective.

If a definition is incomplete or one applied component does not match the requested avatar, the manager restores the pre-transition snapshot instead of leaving a half-Ruvia, half-Grace chimera in the scene tree.

The manager tracks:

- transition count;
- rollback count;
- active avatar;
- manifestation time;
- stable and current actor instance IDs;
- camera ownership;
- current weapon and spell count;
- installed movement-profile paths;
- most recent result and error.

## Watchdog and emergency restoration

While an incarnation is active, the manager periodically verifies that:

- the physical player instance is still the original stable anchor;
- the camera is still the shared player camera;
- all four movement profiles match the active avatar;
- the weapon matches the active avatar;
- the loadout matches the active avatar;
- the wire presentation matches the active avatar.

A contract failure triggers emergency restoration to Grace using the same rollback path. The player remains at the current world position and retains current health and objective state.

This watchdog is a development safety net, not a substitute for authored production transitions.

## Progression gate

Ruvia currently declares:

```text
required_unlock_id = "spellcasting.warlock.mastery"
```

Release builds must satisfy that unlock before a normal incarnation request succeeds.

Debug builds may access definitions marked `debug_available`, allowing the mechanic to be developed long before Grace reaches the narrative unlock.

## Debug control

In a debug build:

```text
F9 = Ruvia ↔ Grace
```

The toggle is handled by `PlayerAvatarManager` on the shared player, so it works in any scene using the standard player scene unless debug input is disabled on that manager.

The motion showcase presents the control explicitly:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

## Ruvia prototype

Ruvia is the first complete avatar-definition test because Fire already has multiple spells and her aggressive identity makes movement-profile differences easy to read.

### Current Fire mastery loadout

```text
data/loadouts/ruvia_fire_mastery_loadout.tres
```

It contains every Fire spell currently registered as a gameplay ability:

- Firebolt;
- Fire Field.

Every equipped ability is validated as Fire. As new Fire spells are added, this prototype loadout must be expanded until a future element-query loadout builder automates the population.

### Prototype signature weapon

```text
data/weapons/ruvia_ember_halberd_prototype.tres
scenes/weapons/prototype_ember_halberd_rig.tscn
```

The weapon provides:

- `halberd` weapon-class identity;
- a custom procedural ember-halberd presentation;
- Fire damage metadata and burning status;
- greater reach than Grace's practice sword;
- Ruvia-specific colors and scaling identity.

The prototype currently borrows the existing spear attack graph. This proves weapon swapping and signature-weapon ownership without pretending the final halberd moveset has already been authored.

### Movement identity

Ruvia has separate profile resources for:

```text
ground motion
dodge motion
combat footwork
vertical motion
```

Compared with Grace, the prototype favors:

- slightly greater travel speed;
- faster initial response;
- more momentum retained into attacks;
- a more aggressive forward dodge;
- less steering during committed attacks;
- stronger launch and landing weight.

These profiles prove that avatar identity can alter feel without forking the player controller.

### Wire presentation

Ruvia currently appears through a Fire-colored incarnation of the diagnostic skeleton:

- scarlet and orange limbs;
- bright ember center line;
- gold joints;
- stronger base emission;
- I-frame glow layered above the avatar's own emission rather than resetting to Grace's baseline.

This is intentionally a mechanic-development presentation. It is not Ruvia's final body, clothing, face, animation set, or VFX treatment.

## Avatar-aware wire renderer

```text
scripts/visuals/avatar_wire_skeleton_renderer.gd
scripts/visuals/grace_incarnation_motion_visual.gd
```

The renderer can:

- install an avatar palette;
- preserve that palette across outfit-change signals;
- capture and restore presentation during rollback;
- report avatar identity in animation diagnostics;
- retain avatar-specific emission through dodge I-frames.

The node path remains:

```text
Player/GraceVisualV1/WireSkeletonRenderer
```

The historical name is preserved so existing VFX, equipment, tests, and gameplay scripts do not break while the avatar architecture matures.

## Automated regression

Run:

```text
scenes/tests/avatar_incarnation_smoke_test.tscn
```

Expected marker:

```text
AVATAR_INCARNATION_SMOKE_TEST: PASS
```

The regression verifies:

- Grace and Ruvia definition validity;
- Fire-only Ruvia spells;
- stable player groups and metadata;
- rejection of an invalid avatar without mutation;
- action quiescence;
- preservation of actor instance, transform, velocity, lock-on, camera, health, and objective;
- replacement of all four movement profiles;
- Ruvia's halberd and runtime rig;
- Ruvia's complete current Fire loadout;
- avatar palette and emission;
- visual and manager diagnostics;
- restoration of Grace's pre-incarnation kit at the god's current location;
- watchdog emergency restoration;
- timed manifestation expiry.

The main Godot validation workflow runs this regression after the wire, ground-motion, dodge, combat-footwork, and vertical-motion tests.

## Manual review

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

Suggested sequence:

1. Move Grace away from the spawn point.
2. Select a non-default Grace spell.
3. Press `F9`.
4. Confirm the same body location and camera remain active.
5. Confirm the wire changes to Ruvia's Fire palette.
6. Confirm the weapon becomes the ember halberd.
7. Open the spell menu and confirm only Firebolt and Fire Field are present.
8. Compare acceleration, forward dodge, jump, and landing with Grace.
9. Attack while moving and while locked on.
10. Walk stairs, jump from the drop platform, and dodge into walls.
11. Move to a new location and lose some health while incarnated.
12. Press `F9` again.
13. Confirm Grace returns at the new location with the current health pool.
14. Confirm Grace's previous sword, movement profiles, and spell loadout return.
15. Repeat swaps during locomotion, immediately after landing, after dodge recovery, and after an attack finishes.

## Current limitations

- The physical body remains Grace's stable proxy rather than a distinct Ruvia model.
- Ruvia uses a Fire-colored wire presentation instead of final character art.
- The ember halberd borrows spear attacks and does not yet have a dedicated halberd graph, footwork catalog, hand path, or divine techniques.
- Fire loadout population is explicit rather than automatically querying every registered Fire ability.
- There is no manifestation meter UI.
- The default debug incarnation has unlimited duration.
- There is no transformation cinematic, sound, rumble, or final VFX.
- The avatar body does not yet accept interchangeable player, AI, cutscene, and replay control drivers.
- Ruvia is not yet available as an autonomous companion or boss through this architecture.
- The Warlock mastery framework's progression unlock still needs its production integration on `main`.

## Next steps

The safest next sequence is:

1. manually validate Grace ↔ Ruvia swapping and repair any parser or runtime errors;
2. author Ruvia's dedicated halberd moveset and complete whole-body weapon performance;
3. build avatar control-driver abstraction for player, AI, cutscene, and replay control;
4. connect the release path to Warlock Mastery and manifestation resource rules;
5. add autonomous manifestation and companion behavior;
6. replace the diagnostic wire incarnation with Ruvia's production model and VFX;
7. use the same avatar definition for future boss and sequel-protagonist foundations.
