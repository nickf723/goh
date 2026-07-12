# Sound Reveal Bridge Puzzle v1

## Goal

Verify the first player-facing Sound traversal puzzle:

```text
listen → reveal → move
```

## Scene

Open:

```text
scenes/levels/prototypes/prototype_sound_reveal_bridge_v1.tscn
```

Run Current Scene.

## Opening state

1. Confirm Grace starts on a solid stone platform.
2. Confirm a second stone platform and orange destination beacon are visible across the gap.
3. Confirm no bridge mesh is visible.
4. Walk carefully toward the gap without casting.
5. Confirm there is no hidden collision supporting Grace.
6. Confirm falling returns Grace to the starting marker rather than defeating or reloading her.
7. Confirm the objective explains that Sound Pulse reveals the path.
8. Confirm Sound Pulse is selected automatically.

## Reveal and expiry

1. Stand near the gap.
2. Cast Sound Pulse.
3. Confirm an orange echo bridge appears across the gap.
4. Confirm the message says Sound outlined a hidden bridge.
5. Wait without crossing.
6. Confirm the bridge disappears after approximately eight seconds.
7. Confirm its collision disappears with the visual.
8. Cast Sound Pulse again and confirm the bridge returns.

## Refresh behavior

1. Reveal the bridge.
2. Wait several seconds.
3. Cast Sound Pulse again before it expires.
4. Confirm the bridge remains available for a fresh reveal window rather than disappearing on the original timer.

## Crossing

1. Reveal the bridge.
2. Walk across at a normal pace.
3. Confirm the bridge collision supports Grace from start to destination.
4. Reach the far platform.
5. Step into the exit marker.
6. Confirm the completion message appears:

```text
The echo path carries Grace across. Sound can reveal what sight cannot.
```

## Regression

Confirm these still work in the room:

- movement and camera;
- jumping and dodging;
- Focus spell selection;
- manual spell switching;
- repeated Sound Pulse casts;
- full menu opening and closing;
- resource HUD updates.

## Creative review

Judge:

- whether eight seconds feels comfortably readable without removing all urgency;
- whether the bridge is visually distinct enough when revealed;
- whether the gap and destination communicate the intended route before casting;
- whether falling feels gentle rather than irritating;
- whether the room teaches Sound's identity without overexplaining it.

## Known limitations

- Prototype primitives and colors only.
- No bespoke sound effect, music, particles, fade, or bridge animation.
- The bridge appears and disappears instantly.
- This room is standalone and is not yet connected to the Church Trial dungeon.
