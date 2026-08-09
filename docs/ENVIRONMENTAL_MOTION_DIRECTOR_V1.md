# Environmental Motion Director v1

## Goal

Environmental Motion Director makes authored environments feel alive without requiring final imported animation rigs or turning presentation wind into gameplay force.

```text
EnvironmentalMotionProfile + spatial Motion Zones + optional real AirflowManager
                                   ↓
                    EnvironmentalMotionDirector3D
                                   ↓
      foliage / canopy / vines / water / waterfall / Grace accessories
```

The system is deliberately quiet. It is intended to add coordinated background motion, not spectacle.

## Core files

```text
scripts/environmental_motion/environmental_motion_profile.gd
scripts/environmental_motion/environmental_motion_zone_3d.gd
scripts/environmental_motion/environmental_motion_director_3d.gd
scripts/visuals/player_accessory_wind_response.gd
```

## Ownership boundary

Environmental Motion may:

- animate presentation-only Node3D transforms;
- apply slow canopy sway;
- bend foliage and hanging vines;
- add tiny water-surface breathing;
- vary waterfall ribbon width/position;
- add a late, additive wind offset to Grace's existing sash/hair animation;
- sample an existing `AirflowManager` so real wind fields can influence visual motion;
- spatially vary ambient visual wind through motion zones.

Environmental Motion must not:

- create ambient gameplay wind just to make foliage move;
- apply force to Grace, enemies, rigid bodies, projectiles, or vehicles;
- move collision geometry;
- replace Grace's normal locomotion/action accessory animation;
- decide weather gameplay;
- decide traversal/combat state;
- own fauna AI.

## Ambient vs systemic airflow

The default breeze in a level is **visual only**. It comes from the motion profile and zones and never enters the physics airflow system.

If an `AirflowManager` appears, the Director discovers it and samples `sample_total_airflow_fast()`. This makes the visual environment respond to real airflow without changing who owns the physics.

A useful example is Wind Well:

1. the Green Grotto normally sways from visual ambient wind;
2. Grace's sash/hair receive a small additive offset from that same visual wind;
3. Wind Well creates/registers a real airflow field through the existing airflow system;
4. nearby enrolled foliage/vines and Grace's accessories receive that local airflow in addition to the ambient visual breeze;
5. the existing airflow system remains the only gameplay-force authority.

## Green Grotto reference integration

Profile:

```text
data/environmental_motion/green_grotto_motion.tres
```

Integration:

```text
scripts/levels/prototype_green_grotto_motion_pass.gd
```

Green enrolls clusters rather than individual leaf meshes:

- fern clusters;
- cycads;
- low ground foliage;
- canopy crowns;
- hanging vines;
- upper stream;
- lower basin;
- four waterfall sheets.

Rock, masonry, structural roots, railings, and collision scaffolding remain static.

The integration also installs `PlayerAccessoryWindResponse` on Grace for the benchmark. This runs after the existing stylized actor pose layer and only adds a small directional sash/hair offset. In a scene with no Environmental Motion Director it contributes nothing.

### Spatial motion zones

```text
EntranceMotionZone
CanopyMotionZone
WaterfallMotionZone
ShrineMotionZone
```

The sheltered entrance receives weaker motion. The canopy opening is breezier and gustier. The waterfall receives more irregular motion. The shrine becomes calmer again so the architecture remains visually stable.

## Benchmark hotkeys

In the Green Grotto art target:

```text
F5  Environmental Motion ON/OFF
F6  Camera Director ON/OFF
F7  Lighting quality tier
```

F5 restores every enrolled environment target to the exact transform captured at registration, making the A/B comparison deterministic. Grace's additive accessory wind naturally decays toward zero while the Director is disabled.

## Performance approach

The Director animates selected cluster roots, not every leaf mesh. Real airflow is sampled on a staggered interval and cached per environment target rather than queried every frame. Ambient wind remains procedural and cheap.

## Validation

```text
res://scenes/tests/environmental_motion_director_smoke_test.tscn
```

The regression verifies:

- Green enrolls a substantial but bounded target set;
- foliage/canopy/vine/water target categories are present;
- spatial zones create different motion intensity;
- ambient motion changes enrolled presentation transforms;
- disabling the Director restores exact authored environment transforms;
- Grace resolves sash/hair pivots and receives the same ambient visual wind;
- Green creates no ambient gameplay AirflowManager;
- a real AirflowManager/AirflowField can be discovered and sampled by the Director;
- real airflow also increases Grace's accessory-wind response.
