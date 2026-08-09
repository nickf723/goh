# Camera Director v1

## Goal

Camera Director is a non-authoritative presentation layer for Grace's existing third-person camera.

The player controller continues to own:

- mouse/right-stick yaw;
- camera pitch;
- lock-on facing and dynamic lock-on pitch;
- spell-camera brush input;
- free-aim input;
- SpringArm collision behavior.

Camera Director owns only **framing**:

- target SpringArm distance;
- Camera3D FOV;
- CameraPivot local position;
- movement lead;
- contextual composition;
- short landing framing transients;
- authored spatial camera-zone offsets.

It never rotates Grace or CameraPivot and it never writes Camera3D `h_offset` / `v_offset`, leaving existing hit/landing presentation impulses intact.

## Core files

```text
scripts/camera/camera_profile.gd
scripts/camera/camera_zone_3d.gd
scripts/camera/camera_director_3d.gd
data/camera/grace_exploration_camera.tres
```

## Grace camera grammar

### Exploration

Base third-person framing. Planar speed gently increases distance and FOV. Local planar velocity adds very small lateral/forward pivot lead so movement has breathing room without changing aim direction.

### Aim / ground placement

Closer, narrower, more stable composition. Movement lead is removed while spell-camera brush, free aim, or shared ground placement owns the interaction.

### Lock-on

Distance and FOV scale with target range. A close target stays intimate; a distant target causes the camera to pull back enough to keep the combat relationship readable. Existing player-controller lock-on pitch remains authoritative.

### Climb

Closer camera with a raised pivot, emphasizing nearby handholds and vertical geometry.

### Swim

Moderately open framing with restrained movement expansion.

### Flight

The widest standard gameplay framing. Distance/FOV open with speed so aerial movement has horizon and route visibility.

### Dodge

Briefly wider framing so fast lateral movement remains readable.

### Defeated

A quieter, tighter framing state.

## Movement transients

`PlayerMotionFeedback.landing_emitted` feeds Camera Director a normalized landing strength. The Director briefly compresses SpringArm target distance and drops the framing pivot, then exponentially recovers. Existing `PlayerMotionFeedback` still owns its small `v_offset` landing impulse, so the two layers complement rather than overwrite one another.

Planar acceleration contributes at most a subtle FOV bonus. This is intentionally small to avoid camera pumping during ordinary directional changes.

## Camera Zones

`CameraZone3D` is an oriented soft box that may add:

- distance offset;
- FOV offset;
- pivot-height offset;
- movement-lead scale.

Zones **never own yaw or pitch**. They are composition suggestions, not cutscene cameras.

Green Grotto reference zones:

```text
CausewayVistaCameraZone
WaterfallCameraZone
ShrineThresholdCameraZone
```

The Causeway Vista opens the shot so the shrine/chasm composition reads. The Waterfall zone raises and opens framing to emphasize the vertical water geography. The Shrine Threshold gently tightens framing as Grace reaches the architectural focal point.

## A/B testing

Green Grotto enables the Camera Director debug hotkey:

```text
F6 = Camera Director OFF / ON
```

Disabling the Director restores the exact CameraPivot position, SpringArm length, and Camera3D FOV captured after level/player initialization. This makes the comparison against the authored pre-Director camera honest.

Green's Lighting Director comparison remains:

```text
F7 = Performance / Balanced / Cinematic lighting
```

Together, F6/F7 let the art target isolate camera and renderer contributions.

## Ownership rules

Camera Director must not decide:

- player input;
- combat targeting;
- spell targeting;
- movement velocity;
- lock-on validity;
- collision outcomes;
- encounter state;
- cutscene progression.

It may read those states to choose framing only.

## Validation

```text
res://scenes/tests/camera_director_smoke_test.tscn
```

The regression checks initialization, exploration speed framing, aim/flight/lock-on contexts, Green camera-zone blending, landing transients, and exact restoration of authored camera values when the Director is disabled.
