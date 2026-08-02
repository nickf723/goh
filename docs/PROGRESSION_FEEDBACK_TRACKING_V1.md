# Progression Feedback and Tracking v1

## Purpose

This layer turns existing progression systems into continuous player-facing feedback without requiring every gameplay scene to author its own notification UI.

## Persistent HUD

`FullMenuDirector` owns a persistent `ProgressionFeedbackHUD` beside the progression tracker. It appears only in gameplay contexts and hides while the full menu is open.

The HUD contains:

- a tracked quest or challenge card beneath the objective
- up to three bundled notification cards
- progress bars for countable updates
- larger presentation for discoveries, achievements, ranks, levels, and rewards

## Challenge and quest pinning

In Codex:

1. Select a Story Quest, Side Quest, or Challenge record.
2. Confirm the already-selected record again.
3. The record becomes the tracked gameplay goal.

The tracked card stores its kind and record ID in the save-slot progression state.

## Notification sources

The feedback layer listens to:

- challenge progress and completion
- reaction and recipe discoveries
- quest starts, stages, and completion
- generic unlocks and achievements
- weapon mastery rank-ups
- Grace level-ups
- creature discoveries, ranks, and capabilities

Repeated updates with the same semantic key replace the existing toast instead of creating notification rain.

## Manual test route

1. Launch the Progression Challenge Laboratory.
2. Open Codex → Challenges.
3. Select Live Wire, then confirm it again.
4. Close the menu and verify the tracked card appears beneath the objective.
5. Trigger Wet Conduction repeatedly and verify one progress toast updates rather than multiplying.
6. Complete Live Wire and verify Chain Lightning receives a larger reward banner.
7. Pin a quest and advance its stage.
8. Perform an undiscovered reaction and verify its Journal discovery banner.
9. Open the full menu and verify the gameplay feedback HUD hides until the menu closes.

## Automated validation

`res://scenes/tests/progression_feedback_tracking_v1_smoke_test.tscn`

Expected:

`PROGRESSION_FEEDBACK_TRACKING_V1_SMOKE_TEST: PASS`
