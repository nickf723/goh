# Large Enemy and Part Breaking v1

## Run

Open:

`scenes/levels/prototypes/prototype_large_enemy_lab_v1.tscn`

## Targeting

- Press **R3** or **T** to hard-lock the Foundry Colossus body.
- Flick the right stick or press **`,` / `.`** to switch toward a visible part.
- Weak points are not normal soft-aim or initial-lock candidates.
- Only the currently selected target receives a lock marker, keeping the giant readable.
- Large-enemy targets request a wider camera composition automatically.

## Parts and consequences

- **Chest Plate:** break it to expose the Arc Core.
- **Arc Core:** transfers heavy damage into the main frame and forces a kneel.
- **Hammer Arm Joint:** drops the physical hammer and replaces the sweep with a smaller stomp.
- **Left or Right Knee:** reduces movement and forces a long vulnerable kneel.
- **Both Knees:** permanently reduce movement further.

The body remains a conventional enemy target with its own health and stance. Breaking parts also transfers a smaller amount of damage and stance pressure into the body.

## Combat behavior

The construct is approximately three times Grace's height. It closes slowly, telegraphs attacks through orange armor charge, and uses broad attacks with long recovery windows.

Its first attack is a hammer sweep. Disabling the weapon arm materially changes its action set to a ground stomp.

## Smoke test

Run:

`scenes/tests/large_enemy_smoke_test.tscn`

The test breaks the chest plate, confirms the core becomes targetable, disables the hammer arm, breaks a leg, and verifies the kneel consequence.
