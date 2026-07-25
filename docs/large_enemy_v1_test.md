# Large Enemy, Part Breaking, and Climbing v1

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

Its first attack is a hammer sweep. Disabling the weapon arm materially changes its action set to a ground stomp. Every third close-range attack is a telegraphed grab attempt.

## Climbing and grab escapes

- Break stance, the core, or a knee to force the Colossus into a five-second kneel.
- Approach a cyan grip and press **Interact / E / B** to attach.
- Use forward/back movement to climb between the boot, knee, hip, chest, shoulder, and core grips.
- Climbing steadily drains stamina; ordinary stamina regeneration resumes after detaching.
- Hold **Interact** when the Colossus shakes to brace at an extra stamina cost.
- Press **Jump** or **Dodge** to leap away intentionally.
- If the Colossus catches Grace, tap **Light Attack** or **Dodge** four times before the escape timer expires.
- A failed escape deals crushing damage and throws Grace away.

The traversal controller is a separate player component driven by anchors and danger events exposed by the large enemy. Future giants can provide different anchor layouts without replacing the ordinary movement controller.

## Smoke test

Run:

`scenes/tests/large_enemy_smoke_test.tscn`

The test breaks the chest plate, confirms the core becomes targetable, disables the hammer arm, breaks a leg, verifies the kneel consequence, mounts the first climb anchor, and confirms an unbraced shake detaches Grace.
