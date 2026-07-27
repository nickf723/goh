# Authored Set Composer v1

The Authored Set Composer turns repeated level-construction code into compact layout data. It exists because hand-positioning every floor, wall, doorway, tunnel, stair, and modular prop makes simple dimension changes expensive and allows connected spaces to disagree about where their shared opening is.

The first story-integrated proof is the collapsed burial passage in **The Drowned Bell**.

## Canonical owners

```text
scripts/environment/authored_set_composer.gd
scripts/environment/authored_set_clearance_auditor.gd
data/set_layouts/
```

The Drowned Bell integration lives at:

```text
scripts/levels/drowned_bell_crypt_layout_pass.gd
data/set_layouts/drowned_bell_crypt_passage_v1.json
```

## What a set plan can build

A plan may contain:

- `corridors`, with explicit interior width and height;
- `walls`, with one or more openings positioned along the wall;
- `stairs`, with visible steps over one continuous walkable ramp;
- `modules`, selected from the existing modular environment catalog;
- `static_boxes` for support geometry;
- `visual_boxes` for lightweight authored dressing.

The composer owns coordinate conversion, naming, metadata, clearance defaults, collision policy, and stable assembly. The authored level still owns circulation, landmarks, mood, environmental history, and which pieces belong in the plan.

## Example

```json
{
  "layout_id": "example_passage",
  "corridors": [
    {
      "id": "SwimPassage",
      "floor_center": [0.0, -5.0, 12.0],
      "forward": [0.0, 0.0, 1.0],
      "length": 10.0,
      "clear_width": 5.8,
      "clear_height": 5.1,
      "traversal": "swim"
    }
  ],
  "walls": [
    {
      "id": "DestinationWall",
      "base_center": [0.0, -3.0, 17.0],
      "length": 14.0,
      "height": 6.0,
      "depth": 0.6,
      "openings": [
        {
          "id": "PassageOpening",
          "center_offset": 0.0,
          "width": 5.8,
          "height": 4.8,
          "traversal": "swim"
        }
      ]
    }
  ]
}
```

The corridor and wall opening now share visible data instead of being inferred from unrelated box positions.

## Clearance standards

The composer publishes player-facing clearance metadata and can enforce minimums:

```text
Land corridor       4.0m wide × 3.8m high
Swimming corridor   5.5m wide × 5.0m high
Camera-comfort path 6.0m wide × 5.0m high
```

The values are prototype standards, not immutable final balance. Their purpose is to prevent ordinary routes from being built around the smallest mathematically possible capsule.

`AuthoredSetClearanceAuditor` checks:

- corridor width and height against traversal mode;
- doorway and wall-opening clearance;
- stair slope and continuous ramp ownership;
- malformed opening metadata.

## Collision policy

Modular placements accept one of three collision modes:

```text
own            Use the module's collision.
support_shell  Display the module over an authored support shell.
none           Presentation only.
```

This keeps visual modular pieces from doubling collision when a polished set is layered over proven blockout geometry.

## Drowned Bell correction

The original crypt passage was hand-built from separate values:

- the tunnel was centered at `x = -1.8`;
- the Listener chamber's front-wall gap was centered at `x = 0`;
- the visible arch was centered on the tunnel;
- the wall segments were not.

The mismatch left only a narrow slice of the apparent opening usable. The new plan defines the tunnel, chamber wall, opening, stairs, water volume, exit anchors, modular trim, and drained return walkway together.

## Promotion rule

Use the composer when a space contains connected repeated construction or when a dimension is likely to change during playtesting. Keep one-off landmarks in authored level code until repetition proves a reusable pattern.

Do not convert every decorative object into layout data. The plan should make structure easier to reason about, not turn the level into a telephone directory with moss.
