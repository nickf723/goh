# Visual LOD Director v1

## Goal

Visual LOD reduces draw cost from small procedural environment details that no longer contribute meaningfully at distance, while preserving the large silhouettes and gameplay geometry that define the level.

The first Green Grotto pass uses Godot `GeometryInstance3D` visibility ranges instead of performing manual camera-distance checks over hundreds of nodes every frame.

## F7 quality contract

Visual LOD follows Lighting Director quality and therefore the existing F9 presets.

### Performance

```text
foliage             24 m
canopy detail       58 m
surface detail      22 m
architecture detail 32 m
hysteresis margin   2.5 m
```

### Balanced

```text
foliage             38 m
canopy detail       78 m
surface detail      36 m
architecture detail 52 m
hysteresis margin   4 m
```

### Cinematic

```text
foliage             58 m
canopy detail       115 m
surface detail      60 m
architecture detail 78 m
hysteresis margin   5 m
```

Green is compact enough that Cinematic keeps almost all authored detail visible across normal gameplay views, while Performance is considerably more aggressive.

## Green categories

The integration intentionally uses simple authored seams instead of a heuristic that can unexpectedly hide new content.

### Foliage

Every mesh whose ancestry belongs to a `Fern*`, `Cycad*`, or `GroundLeaf*` cluster.

This means stems and leaf meshes disappear together rather than leaving distant bare sticks.

### Canopy detail

Vegetation presentation targets marked with the `canopy` role, plus explicit `CanopyCrown*` / `CanopyInner*` meshes.

The range is significantly longer than ordinary ground foliage because the canopy contributes to the grotto silhouette.

### Surface detail

Small dressing whose names contain `Moss` or `Litter`, plus authored `Crack*` meshes.

### Architecture detail

Small construction elements containing `Bracket`, `RoofTile`, `Finial`, or `Railing` in their authored node names.

## Explicit exclusions

Visual LOD does not enroll:

- causeway slabs or major walkable paving;
- major chasm rock masses;
- shrine silhouette/foundation masses;
- water surfaces;
- Grace;
- fauna;
- collision shapes;
- gameplay nodes.

The system fails safe toward rendering too much. Unrecognized geometry remains fully visible.

## Hysteresis instead of transparent fading

V1 uses `VISIBILITY_RANGE_FADE_DISABLED` with an end margin. Godot treats that margin as hysteresis, preventing rapid threshold flicker while keeping opaque geometry out of the transparent rendering pipeline.

Smooth self-fading remains available to future authored HLOD assets, but it is intentionally not used for hundreds of tiny procedural details.

## Runtime behavior

The Director only reacts when the F7 quality tier changes. It writes visibility-range metadata onto enrolled `GeometryInstance3D` objects and lets the renderer perform distance culling.

It does **not** iterate through targets every frame to calculate camera distances.

## Ownership boundary

Visual LOD may:

- author renderer visibility ranges on enrolled presentation geometry;
- change those ranges with renderer quality;
- restore the exact previous range values when disabled.

Visual LOD must not:

- hide gameplay collision;
- alter transforms or meshes;
- alter gameplay state;
- remove nodes from the scene tree;
- decide content importance without explicit enrollment rules.

## Validation

```text
res://scenes/tests/visual_lod_director_smoke_test.tscn
```

The regression verifies:

- a substantial Green detail set is enrolled;
- all four semantic LOD categories exist;
- F7 changes exact visibility ranges;
- hysteresis/fade-disabled behavior is used;
- water, major causeway structure, Grace, and fauna are excluded;
- disabling the Director restores every original visibility-range property;
- no gameplay/collision authority is introduced.
