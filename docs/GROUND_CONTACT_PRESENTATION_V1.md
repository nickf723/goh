# Ground Contact Presentation v1

## Goal

Ground Contact Presentation gives semantic footsteps and landings a restrained material-aware visual response without changing locomotion, collision, audio, or gameplay surface rules.

The first integration is the Green Grotto benchmark.

## Event pipeline

```text
PlayerMotionFeedback
    ↓
GamePresentationDirector footstep / landing event
    ↓
GroundContactPresentationDirector3D
    ↓
contact-surface ray sample
    ↓
one pooled MultiMesh particle response
```

The Ground Contact Director does not detect stride timing itself. It listens to the Presentation Director's already-authored semantic movement events.

## Surface vocabulary

The shared renderer understands detailed `contact_surface` metadata when a collider provides it.

Green currently authors:

```text
moss_soil
paving
wet_stone
stone
```

The existing generic `presentation_material` value remains unchanged, so material-aware audio can continue hearing `stone` while contact visuals distinguish paving from wet rock or mossy soil.

## Green authoring

`GreenGrottoGroundContactAdapter` labels the existing collision scaffold only.

Examples:

```text
ArrivalShelf                  → moss_soil
CausewaySlab00..06            → paving
ShrineFoundation              → paving
LeftTerrace                   → paving
RightTerrace/RightBrokenLedge → wet_stone
cliff/rock masses             → stone
```

No collision shape is created or modified.

## Rendering

Ground Contact uses one fixed MultiMesh pool rather than spawning particle nodes per step.

The pool contains a small low-poly chip mesh. Individual instances carry transient position, velocity, scale, and color state.

Surface families produce different responses:

- stone/paving: tiny dry dust or grit chips;
- moss/soil: slightly denser green-brown loose material;
- wet stone: shorter cool droplets/flecks.

Landings scale the same grammar upward instead of introducing a separate effect system.

## F7 quality

Ground Contact follows Lighting Director quality and therefore F9 benchmark presets.

### Performance

```text
contact detail density = 0
```

### Balanced

```text
contact detail density = 62%
```

### Cinematic

```text
contact detail density = 100%
```

The existing PlayerMotionFeedback pulse and semantic movement event remain independent.

## Ownership boundary

Ground Contact may:

- listen to semantic movement presentation events;
- raycast only when those events occur;
- inspect presentation-only `contact_surface` metadata;
- render transient pooled visual chips;
- scale visual density with renderer quality.

Ground Contact must not:

- alter collision;
- apply forces;
- change traction or movement;
- decide footstep timing;
- decide sound propagation;
- define whether a surface is wet, slippery, damaging, or interactable for gameplay.

## Validation

```text
res://scenes/tests/ground_contact_presentation_smoke_test.tscn
```

The regression verifies:

- Green contact metadata is authored on the existing collision scaffold;
- arrival and causeway raycasts resolve detailed surfaces;
- Performance emits no pooled contact detail;
- Balanced emits reduced density;
- Cinematic landing feedback is stronger;
- one fixed MultiMesh pool owns the visual chips;
- collision and gameplay authority remain untouched.
