# Stoneback Salamander Laboratory v1

## Run

Open:

`scenes/levels/prototypes/prototype_stoneback_salamander_lab_v1.tscn`

## Purpose

The Stoneback is the second consumer of the large-enemy framework and the first living titan. It reuses body-first targeting, directional part selection, stance topples, moving climb anchors, stamina climbing, bracing, and grab escapes without inheriting the Foundry Colossus anatomy or combat identity.

## Element reactions

- **Water:** applies Wet for eight seconds.
- **Lightning while Wet:** strongly amplifies health and stance pressure.
- **Fire:** applies Overheated for seven seconds.
- **Ice while Overheated:** produces amplified thermal-shock stance damage.
- **Earth or Ice:** efficiently cracks the Mineral Back Plate.
- **Water, Ice, or Poison:** exploit the exposed Heat Organ.

The blue and orange pools are visual teaching stations; cast the matching spells at the creature itself.

## Parts

- **Mineral Back Plate:** breaks away and exposes the Heat Organ.
- **Heat Organ:** causes catastrophic body damage and a topple.
- **Crown Horn:** disables future bite-grab attacks.
- **Left Foreleg:** reduces movement and forces a long vulnerable topple.

## Living attacks

The creature alternates between a broad Tail Sweep and a heavier Body Slam. Every fourth close-range attack becomes a Bite Grab while the Crown Horn remains intact. Escape with four Light Attack or Dodge inputs before the timer expires.

## Climbing

Topple the creature through stance damage, the foreleg, or its exposed organ. Press Interact near a cyan anchor and climb from tail to rear shell, mid-back, shoulders, neck, and heat organ. The anchors move with breathing and bucking rather than forming a fixed vertical ladder. Hold Interact to brace against the late-window buck.

## Controls

- **R3 / T:** lock body
- **Right stick / comma / period:** select parts
- **Right mouse / ZL:** toggle Focus spell menu
- **Q / ZR:** cast
- **Interact:** mount or brace
- **Move forward/back:** traverse anchors
- **Jump / Dodge:** leap away
- **Light Attack / Dodge:** escape bite
- **F8:** reset

## Smoke test

Run:

`scenes/tests/stoneback_salamander_smoke_test.tscn`

The test verifies biological identity, six moving anchors, Wet conduction, shell break and organ exposure, foreleg topple, and debug state.
