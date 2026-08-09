# Environmental Interaction v1

## Goal

Environmental Interaction makes presentation foliage react to nearby moving actors without creating gameplay force, moving collision, or introducing a second transform authority.

The system extends the existing Environmental Motion stack:

```text
Ambient visual wind
+ real AirflowManager fields
+ EnvironmentalMotionInfluencer3D actors
                ↓
     EnvironmentalMotionDirector3D
                ↓
      one final presentation pose
```

Environmental Motion remains the only system writing enrolled foliage transforms.

## Influencer

```text
scripts/environmental_motion/environmental_motion_influencer_3d.gd
```

An influencer is a lightweight presentation component attached to an actor. It describes:

- local interaction radius;
- approximate body radius and vertical reach;
- idle contact strength;
- velocity-driven wake strength;
- maximum visual strength;
- how strongly actor travel direction biases the wake.

The component reads its parent `CharacterBody3D.velocity` when available. It never applies force to its parent or to the environment.

## Motion integration

`EnvironmentalMotionDirector3D` discovers influencers sharing its channel and samples them while solving enrolled targets.

Only these v1 target categories accept body interaction:

```text
foliage
vine
```

Canopy, roots, water, waterfalls, masonry, rocks, and collision geometry ignore actor proximity.

Foliage receives:

- directional bend away from the actor / into the travel wake;
- a small presentation-only horizontal displacement;
- restrained vertical compression;
- smooth rebound after the actor leaves.

Vines receive directional bend and a smaller displacement.

## Green Grotto

Grace receives one influencer at:

```text
Player/EnvironmentalMotionInfluencer
```

It uses the existing `green_grotto_motion` channel. The interaction radius is intentionally intimate so Grace must actually brush past vegetation before it responds.

Running or dodging through the same foliage produces a stronger response than standing still because the influencer incorporates real horizontal velocity.

## F5 ownership

Environmental Interaction does not receive another benchmark hotkey.

```text
F5 Environmental Motion ON/OFF
```

F5 controls ambient sway, systemic airflow response, and local actor interaction as one presentation family. Turning F5 off restores every enrolled target to the exact transform captured at registration, including targets that Grace was actively disturbing.

## Ownership boundary

Environmental Interaction may:

- sample actor position and velocity;
- bend presentation-only foliage/vines;
- add small presentation-only displacement/compression;
- support multiple future influencers such as enemies, mounts, fauna, or vehicles.

Environmental Interaction must not:

- move collision geometry;
- apply force or velocity to Grace or other gameplay actors;
- affect navigation/pathfinding;
- decide stealth or detection;
- create persistent world-state consequences;
- own foliage damage/destruction;
- replace AirflowManager as wind/force authority.

## Validation

```text
res://scenes/tests/environmental_interaction_smoke_test.tscn
```

The regression verifies:

- Green installs exactly one Grace influencer;
- the influencer is presentation-only;
- idle physical contact produces a restrained response;
- sprint velocity strengthens the response;
- canopy targets reject body interaction;
- the final foliage transform differs from ambient wind alone;
- F5 restores exact authored position, rotation, and scale;
- no collider or gameplay-force authority is introduced.
