# Avatar Control Drivers and Ruvia Manifestation v1

## Purpose

Divine Incarnation proved that a `PlayableAvatarDefinition` can replace Grace's active movement, weapon, spell, authority, and presentation kit while the stable player anchor keeps the camera, health, world state, and progression identity.

Manifestation proves the complementary case: the same avatar definition can inhabit a separate autonomous body beside Grace.

The control contract is now:

```text
player input ───────────────┐
companion decisions ───────┼─> AvatarActionIntent ─> avatar body and kit
scripted sequence ─────────┘
```

A control driver decides what the avatar intends. The actor, movement motor, weapon graph, elemental authority, and animation systems remain responsible for performing it.

## Control drivers

### AvatarActionIntent

`scripts/avatars/avatar_action_intent.gd`

The intention packet can carry:

- planar movement direction and strength;
- facing direction;
- desired target;
- exact attack form;
- exact spell;
- dodge direction and kind;
- guard or recall requests;
- a decision tag and player-facing diagnostic reason.

### PlayerAvatarControlDriver

`scripts/avatars/player_avatar_control_driver.gd`

The player driver is observation-only in v1. It translates current input into the shared intention vocabulary while leaving the polished direct player-control path untouched. Grace and player-controlled Ruvia therefore retain their existing movement, dodge, combat, and spell response.

This gives future refactors a stable action boundary without replacing proven controls prematurely.

### CompanionAvatarControlDriver

`scripts/avatars/companion_avatar_control_driver.gd`

The companion driver reads:

- Grace's position and lock-on target;
- hostile distance and clustering;
- Burning state;
- Ruvia-owned Fire Fields;
- whether Ruvia or her target is inside a field;
- current action readiness;
- separation and stuck state.

Ruvia's scene uses `RuviaManifestationControlDriver`, a thin specialist adapter over the generic companion driver. It preserves the common `companion_ai` contract while giving failed actions a stable retry rhythm and exposing Ruvia-specific diagnostics.

It uses Ruvia's authored combat vocabulary rather than generic companion attacks:

```text
distant target         -> Firebolt or close distance
crowded at close range -> Haft Check, then Fire Field
near owned field       -> Reaping Hook
inside owned field     -> Scorching Thrust and burning wake
field plus cluster     -> Ember Wheel flare
Burning cluster        -> Solar Descent
ideal range            -> Cinder Sweep / Backdraft Return
```

### ScriptedAvatarControlDriver

`scripts/avatars/scripted_avatar_control_driver.gd`

The scripted driver executes deterministic intention steps. It is intended for:

- tutorials;
- cinematics;
- divine entrances;
- one-action Invocations;
- regression tests;
- replayable demonstrations.

## ManifestedAvatarActor

The reusable scene is:

```text
scenes/actors/avatars/manifested_avatar_actor.tscn
```

It contains:

```text
RuviaManifestedAvatarActor
├── GraceVisualV1 / AvatarWireSkeletonRenderer
├── StepUpController
├── GroundMotionMotor
├── VerticalMotionController
├── ManifestedCombatFootworkController
├── ManifestedElementalAuthorityController
├── ManifestedAvatarStatusReceiver
├── ManifestedWeaponController
├── PlayerWeaponControlAnimator
├── PlayerActionState
├── ManifestedDodgeController
└── RuviaManifestationControlDriver
```

`ManifestedAvatarActor` is the reusable body contract. `RuviaManifestedAvatarActor` is the current patron-specific adapter. The scene accepts a `PlayableAvatarDefinition`, but its v1 elemental and decision adapters are deliberately Ruvia-focused. A second god will prove which remaining pieces should move into generic data and which should remain specialist behavior.

The actor deliberately does not own:

- the player camera;
- inventory or quick items;
- quest interactions;
- save-slot identity;
- the player HUD;
- Grace's mana or stamina pools.

## Resource isolation

Manifested attacks duplicate the selected weapon form and set its runtime stamina cost to zero. Manifested authority spells use a local cost path and never spend Grace's mana, stamina, or focus.

This is not the final companion resource balance. It is the first safe ownership rule: autonomous actions cannot silently drain the player's controls.

## Friendly-fire rules

The manifestation body has no combat collision layer, but still collides with authored environment through its mask. Grace and Ruvia receive mutual collision exceptions, preventing doorway traps.

The Ruvia adapter also removes the manifestation from `combat_targetable`, so Grace's lock-on and soft-aim candidate search cannot select her.

The manifested weapon controller filters:

- Grace;
- player-group actors;
- friendly actors;
- the manifestation's mortal owner.

Manifested Firebolt uses `ManifestedGenericProjectile`, which ignores Grace, friendly actors, and its mortal owner for its entire lifetime.

Manifested Fire Fields use `ManifestedFireField`, which refuses to apply Burning to Grace or friendly actors. Hostile targets retain the normal Fire Field, Burning, flare, and reaction behavior.

## Movement and recovery

The autonomous body uses the same profile-driven movement stack as the playable version:

- Ruvia ground acceleration and braking;
- Ruvia vertical profile;
- Ruvia dodge curve;
- Ruvia Plant / Drive / Settle attack footwork;
- shared stair traversal;
- shared wire animation and two-handed halberd control.

The companion maintains a side formation when idle. If separated beyond the hard limit or unable to make meaningful progress while trying to move, it requests a safe recall beside Grace.

Safe placement uses multiple candidate offsets, a downward floor probe, slope validation, and capsule-clearance testing.

## PlayerManifestationManager

The shared player now owns:

```text
Player/ManifestationManager
```

It enforces:

- one manifested god at a time;
- safe spawn and recall placement;
- debug toggle access;
- timed expiry when a definition supplies a duration;
- cleanup of attacks, dodges, targets, and owned fields;
- dismissal on defeat;
- dismissal before Divine Incarnation transfers control.

Debug controls:

```text
F9  Divine Incarnation: Grace <-> Ruvia
F10 Manifestation: summon or dismiss autonomous Ruvia
```

Pressing F9 while Ruvia is manifested dismisses the autonomous body before the stable player proxy installs Ruvia's playable kit. This prevents two simultaneous instances of the same patron.

## Showcase

Open:

```text
scenes/levels/prototypes/prototype_animation_showcase_lab_v1.tscn
```

The Fire specialist bay now includes an F10 manifestation marker and HUD diagnostics for:

- active driver;
- target;
- chosen action;
- decision reason;
- target range;
- cluster count;
- Burning state;
- pending field or projectile weave;
- owned fields;
- stuck timer;
- recall count.

Suggested review:

1. Press F10 and inspect Ruvia's formation behavior before entering the target cluster.
2. Approach the distant targets and watch her choose between closing and Firebolt.
3. Crowd her near the closest target and look for Haft Check followed by Fire Field.
4. Move a target near an owned field and watch for Reaping Hook.
5. Keep Ruvia inside an owned field and watch for Scorching Thrust.
6. Cluster Burning targets and watch for Solar Descent.
7. Run up and down the staircase while Ruvia follows.
8. Move far enough to trigger safe recall.
9. Confirm Grace cannot lock onto Ruvia and Ruvia's Firebolt and Fire Fields cannot harm Grace.
10. Press F9 while she is manifested. She should dismiss before control transfers.
11. Return to Grace with F9, then press F10 to manifest her again.

## Regression

Focused scene:

```text
scenes/tests/avatar_control_driver_manifestation_smoke_test.tscn
```

Expected marker:

```text
AVATAR_CONTROL_DRIVER_MANIFESTATION_SMOKE_TEST: PASS
```

The regression checks:

- player-driver installation without replacing direct controls;
- separate autonomous actor identity;
- camera preservation;
- Ruvia movement, weapon, authority, and wire contracts;
- no Grace mana or stamina spending;
- ally-safe manifested Firebolt and Fire Fields;
- exclusion from Grace's targeting candidates;
- hostile-target selection and meaningful companion intention;
- deterministic scripted intention;
- safe recall;
- automatic dismissal before Divine Incarnation;
- restoration to Grace afterward.

## Deliberate v1 boundaries

- The manifested body uses the diagnostic wire presentation rather than final Ruvia art.
- Companion balance is not final.
- Ruvia has no autonomous dialogue or relationship reactions yet.
- Enemy AI does not deliberately retarget the manifestation yet.
- The companion has local health plumbing, but encounter-facing defeat balance remains future work.
- There is no production manifestation cost, covenant meter, or cooldown yet.
- Invocation will build on the scripted driver rather than creating another summon architecture.
- A second god remains the next proof that the actor shell and driver contract generalize beyond Ruvia.
