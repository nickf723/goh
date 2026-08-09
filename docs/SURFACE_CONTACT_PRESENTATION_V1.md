# Surface Contact Presentation v1

## Goal

Surface Contact Presentation makes locomotion feel physically connected to authored environments without adding a second footstep detector or a new audio system.

Grace already reports semantic `footstep` and `landing` events through `GamePresentationDirector`. Those events include world position, inferred floor material, and strength. Surface Contact listens to the existing event stream and adds only a small environment-facing visual response.

## Architecture

```text
PlayerMotionFeedback
        ↓
GamePresentationDirector
(footstep / landing + position + material + strength)
        ↓
SurfaceContactPresentationDirector3D
        ↓
small temporary visual pieces
```

There is no second floor raycast in the contact layer.

## F7 quality contract

The system follows Lighting Director quality and therefore the F9 benchmark presets.

### Performance / BASELINE

```text
footstep  0 pieces
landing   0 pieces
```

### Balanced

```text
footstep  3 pieces
landing   7 pieces
```

### Cinematic / HERO

```text
footstep  5 pieces
landing   11 pieces
```

The live-piece budget is capped at 72. Temporary pieces are automatically removed after their short presentation tween.

## Green Grotto contact regions

### Arrival shelf

```text
style: dust
```

Warm, low-opacity dry dust.

### Waterfall bowl

```text
style: damp
```

Cool, soft contact mist around the wet basin/waterfall area.

### Shrine court

```text
style: leaf_litter
```

Small flat brown/green pieces lift and rotate from the old terrace paving.

### Unmarked causeway

Falls back to the semantic floor material. Stone receives a restrained neutral dust contact.

## Existing movement feedback

Green retains the shared `PlayerMotionFeedback` system, including its camera and semantic-event responsibilities. The benchmark caps its generic blue movement-ring visual scale to a faint value so the surface-aware contact layer becomes the dominant environment cue without deleting shared infrastructure.

No final audio work is added by this system.

## Ownership boundary

Surface Contact Presentation may:

- listen to existing presentation events;
- resolve authored regional visual styles;
- spawn temporary presentation-only contact pieces;
- scale density with F7 quality.

It must not:

- perform gameplay floor detection;
- alter locomotion or collision;
- apply force;
- add or own audio;
- decide material gameplay properties such as slipperiness;
- persist footprints or world state;
- replace the authoritative movement/presentation event systems.

## Validation

```text
res://scenes/tests/surface_contact_presentation_smoke_test.tscn
```

The regression verifies:

- the Director connects to the existing presentation service;
- exactly three Green regional overrides exist;
- Performance produces no contact pieces;
- Balanced and Cinematic use exact density budgets;
- arrival, waterfall, shrine, and generic causeway resolve the intended styles;
- the live-piece cap remains bounded;
- no additional raycast, audio, or gameplay authority is introduced.
