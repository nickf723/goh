# Global Playability Framework v1

The Global Playability Framework provides reusable safety and readability contracts beneath authored level design. It does not replace composition, lighting, environment art, encounter pacing, or human playtesting.

## Goals

Every authored space should be able to guarantee that:

- Grace cannot fall forever;
- leaving declared playable bounds returns her safely;
- recovery cancels unstable locomotion and combat states;
- Blink chooses a supported, unobstructed destination inside the playable space;
- swimming volumes expose deliberate exits;
- required quest beats can opt into consistent world guidance;
- CI can detect missing recovery, water-exit, interaction, and guidance contracts.

## Shared components

### `PlayableSpace3D`

Path: `scripts/quality/playable_space_3d.gd`

Declares optional bounds, minimum recovery height, default and active recovery transforms, forbidden volumes, and optional last-resort boundary collision.

### `PlayerRecoveryController`

Path: `scripts/player/player_recovery_controller.gd`

Installed on the shared player scene. It records stable grounded transforms, watches explicit playable-space bounds, restores Grace after falls or recovery-volume contact, clears incompatible movement states, and grants brief recovery invulnerability. Scenes without an explicit `PlayableSpace3D` retain fallback recovery to their initial spawn.

### `SafeDestinationQuery`

Path: `scripts/quality/safe_destination_query.gd`

Validates supporting ground, floor slope, actor clearance, forbidden volumes, and playable bounds. It searches backward from an unsafe request toward a known-safe start position. Space Blink is the first production consumer.

### `PlayableRecoveryVolume3D` and `PlayableForbiddenVolume3D`

Paths:

```text
scripts/quality/playable_recovery_volume_3d.gd
scripts/quality/playable_forbidden_volume_3d.gd
```

Recovery volumes immediately request player recovery. Both volume types reject safe-destination queries.

### `SwimmingExitAnchor3D`

Path: `scripts/quality/swimming_exit_anchor_3d.gd`

Associates a safe landing transform with a swimming volume. The shared swimming controller checks nearby anchors before its older climbable-surface handoff. Natural ramps remain preferred; anchors provide readable backup exits.

### `QuestGuidanceTarget3D`

Path: `scripts/quality/quest_guidance_target_3d.gd`

Provides flag-aware world markers and distance labels for authored objectives. Levels decide which beats need markers and whether they are primary or optional.

### `PlayableSpaceAuditor`

Path: `scripts/quality/playable_space_auditor.gd`

Checks the objective contracts CI can evaluate:

- player recovery controller presence;
- explicit playable-space recovery anchor;
- story-interactable collision;
- required guidance targets;
- swimming-volume exit coverage;
- recovery-volume coverage.

Warnings do not replace manual testing. The auditor cannot judge sightlines, atmosphere, path composition, pacing, or whether a route feels natural.

## Drowned Bell integration

`DrownedBellPlayabilityPass` composes the shared framework into the existing quest without extending the quest director. It adds:

- explicit playable bounds;
- shore, causeway, and chapel recovery anchors;
- a void recovery volume and deep catch floor;
- two authored pool exits plus physical escape steps;
- a gentler visible current;
- climbable backup ledges;
- guidance for Orin, the listening point, the chapel entrance, all three clues, the tuning plate, and the crypt seal.

## Authored-space quality gate

Before expanding an authored scene with another quest beat:

1. Complete the route without Blink, Flight, or development shortcuts.
2. Deliberately walk visible boundaries and confirm recovery.
3. Enter and exit every swimming volume from several orientations.
4. Use mandatory interactables with controller and keyboard.
5. Test Blink against walls, gaps, water, ledges, and bounds.
6. Reload at meaningful quest stages.
7. Confirm completed prompts and guidance disappear.
8. Run the playable-space auditor.
9. Perform a human playtest for clarity and feel.

The framework owns safety, recovery, consistency, and basic detectability. Authored levels still own beauty, mystery, staging, and memory.
