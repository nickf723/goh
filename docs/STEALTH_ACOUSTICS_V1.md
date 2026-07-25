# Stealth and Unified Acoustics v1

Run:

`scenes/levels/prototypes/prototype_stealth_acoustics_lab_v1.tscn`

## Controls

- Left Stick Click / Ctrl: toggle crouch
- Interact behind an unaware enemy while crouched: silent takedown
- Cast: Echolocation
- Interact with the distant bell: create a distraction
- V: toggle perception geometry
- F8: reset the laboratory

## Shared acoustic contract

The existing perception stimulus manager now receives a common acoustic vocabulary from:

- footsteps
- landing impacts
- light and heavy weapon attacks
- spellcasting
- authored distractions
- Echolocation

Events retain position, loudness, duration, priority, source, category, and tags. Acoustic tags identify frequency profile, surface, movement, magic, and Echolocation.

Footstep and landing loudness respond to grass, dirt, wood, stone, metal, and water. Crouching and concealment reduce generated loudness.

## Stealth contract

Crouching changes:

- movement speed
- Grace's collision height and visible pose
- camera height
- footstep loudness
- enemy effective vision range
- enemy visibility strength

Tall grass applies an additional concealment multiplier. Attacking or casting breaks crouch and emits a louder stimulus. Echolocation reveals its ordinary detection targets while also generating a powerful broadband sound that enemies can investigate.

## Playtest route

1. Walk down the center stone lane and watch the noise and enemy suspicion.
2. Toggle crouch and repeat the approach.
3. Compare grass, stone, and metal footsteps.
4. Enter tall grass and confirm CONCEALED appears.
5. Ring the distant bell and move while enemies investigate it.
6. Approach an unaware enemy from behind while crouched and use Interact.
7. Cast Echolocation from concealment and confirm enemies investigate Grace's pulse origin.
8. Steal the patrol plans while crouched or concealed.

Smoke test:

`scenes/tests/stealth_acoustics_smoke_test.tscn`
