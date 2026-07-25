# Fluid Weapon Combat v1

## Run

Open:

`scenes/levels/prototypes/prototype_combat_feel_lab_v1.tscn`

This laboratory intentionally contains only Grace, one responsive dummy, a lined floor, and a compact state display.

## Shared combat upgrades

- Attack inputs buffer for 0.38 seconds in the laboratory.
- Movement input influences the attack heading at startup without instantly rotating the player/camera rig.
- A nearby target inside the assist cone receives a limited facing correction rather than a full forced lock.
- Each attack caches its heading so the strike geometry, lunge, and reaction agree.
- Attack lunges blend with existing horizontal velocity instead of replacing it in one frame.
- Connected attacks trigger directional recoil and a small camera impulse.
- Missed attacks receive additional recovery, preserving a readable cost for whiffing.
- Late cancel permissions still come from each attack definition.
- The responsive dummy distinguishes clean and guarded contact and springs back to its home position.

## Sword graph

- Light → Opening Cut
- Light, Light → Returning Cut
- Light, Light, Light → Rising Cut
- Light chain finisher → Circular Cut
- Light → Heavy branches into Rising Break
- Later Light → Heavy branches into different cleaves, thrusts, and finishers
- Any Heavy → Light branches into the new fast Reprise Thrust
- Reprise → Light rejoins the normal chain at Returning Cut

## Controls

Use the normal weapon controls:

- **Light Attack:** J / left mouse / left shoulder
- **Heavy Attack:** K / Mouse 4 / right shoulder
- **Movement during attack startup:** influences attack direction
- **Dodge:** cancels attacks whose cancel window is open
- **G:** toggle dummy guard
- **H:** toggle attack hitbox visualization
- **F8:** reset

## What to evaluate

1. Tap Light repeatedly, including slightly before each attack finishes.
2. Hold a movement direction while beginning an attack.
3. Stand slightly off-axis and judge whether facing assist helps without stealing control.
4. Press Heavy after different Light attacks.
5. Begin with Heavy, then press Light for Reprise Thrust.
6. Attack empty space and compare whiff recovery with connected recovery.
7. Toggle Guard and compare recoil, color, numbers, and contact text.
8. Dodge during early and late portions of a Light attack.

## Smoke test

Run:

`scenes/tests/combat_feel_smoke_test.tscn`

The smoke test validates the combo graph, Light/Heavy branching, Heavy/Light Reprise, clean contact, guarded contact, and directional recoil.
