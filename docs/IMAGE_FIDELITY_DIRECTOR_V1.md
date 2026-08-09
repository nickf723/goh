# Image Fidelity Director v1

## Goal

Image Fidelity defines the final anti-aliasing and image-clarity policy for the Green visual benchmark. It exists because improved lighting, thin foliage, specular materials, water and small architecture can still look inexpensive if the final image crawls, shimmers, bands, or smears during camera motion.

The system follows Lighting Director quality. It receives no additional benchmark hotkey.

## F7 quality contract

### Performance / BASELINE

```text
TAA             off
3D MSAA         off
screen-space AA off
debanding       off
roughness limit off
```

Performance intentionally stays raw so the F9 BASELINE preset does not smuggle an anti-aliasing upgrade into the comparison.

### Balanced

```text
TAA             off
3D MSAA         2x
screen-space AA off
debanding       on
roughness limit on
```

Balanced now favors non-temporal 2x MSAA. The Green Grotto camera exposed visible softness and ghost-like accumulation under TAA, so the exploration target prioritizes crisp motion and stable geometry edges instead of temporal reconstruction.

### Cinematic / HERO

```text
TAA             off
3D MSAA         2x
screen-space AA off
debanding       on
roughness limit on (slightly stronger)
```

Hero deliberately keeps the same non-temporal AA policy. Its additional image quality comes from the stronger roughness-limiter tier and the rest of the Cinematic renderer stack rather than reintroducing motion smear.

## Roughness limiter

Balanced and Cinematic enable Godot's screen-space roughness limiter. The limiter reduces high-frequency specular aliasing by increasing apparent roughness where normal variation exceeds a configured threshold.

Green uses:

```text
Balanced  amount 0.25  limit 0.18
Cinematic amount 0.32  limit 0.15
```

## Lifecycle

The visual lab captures the viewport's pre-existing TAA, debanding, MSAA and screen-space-AA values before applying its quality policy.

When Image Fidelity is disabled or the Green benchmark leaves the scene tree, those captured values are restored. The project-wide roughness-limiter defaults are restored as well.

This prevents Green's benchmark settings from leaking into unrelated scenes.

## Benchmark integration

`VisualBenchmarkDirector` installs the Green image-fidelity controller dynamically and reports its current state in the development HUD:

```text
RAW
2x MSAA
```

F9 therefore controls the final-image policy through the same BASELINE / BALANCED / HERO preset flow used by the rest of the renderer stack.

The benchmark overlay starts hidden for normal presentation review. F10 still toggles it on whenever renderer telemetry is needed.

## Ownership boundary

Image Fidelity may:

- change active Viewport anti-aliasing/debanding settings;
- toggle the screen-space roughness limiter;
- follow renderer-quality changes;
- restore prior values on disable/scene exit.

It must not:

- change gameplay simulation;
- alter render resolution or dynamic resolution in v1;
- alter camera FOV/framing;
- modify materials/meshes;
- persist benchmark settings globally after the lab exits.

## Validation

```text
res://scenes/tests/image_fidelity_director_smoke_test.tscn
```

The regression verifies exact Performance, Balanced and Cinematic viewport settings plus restoration of the pre-lab Viewport state.
