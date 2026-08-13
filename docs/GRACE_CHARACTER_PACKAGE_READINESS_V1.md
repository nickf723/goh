# Grace Character Package Readiness V1

## Purpose

Provide one migration ladder for replacing the procedural Grace proxy with a production humanoid asset without changing gameplay authority.

Canonical report:

```text
res://scripts/visuals/grace_character_package_auditor.gd
```

The report combines the existing humanoid skeleton contract, imported animation contract, and imported material enrollment status.

## Migration ladder

A character package progresses through these gates in order:

```text
1. map_humanoid_skeleton
2. supply_core_animation_library
3. supply_sword_calibration_library
4. enroll_imported_material_surfaces
5. resolve_material_surface_roles
6. ready_for_character_playtest
```

These gates are intentionally incremental. A production model does not need every animation and final material role before it can begin replacing parts of the procedural presentation.

## Skeleton gate

The imported `Skeleton3D` must satisfy `GraceHumanoidRigContract`.

Required semantics include pelvis, spine/chest, head, both arm chains, both hand bones, both leg chains, and both feet. Godot humanoid-profile names and common Mixamo names are supported.

Godot `BoneMap` + `SkeletonProfileHumanoid` remains responsible for retargeting. Grace code owns only gameplay-facing semantic roles.

## Core animation gate

The minimum imported movement/reaction library is:

```text
idle
run
jump
fall
land
dodge
hit
```

Optional quality clips such as walk, locomotion start/stop, turns, and stagger may arrive later.

Gameplay continues to own movement speed, acceleration, dodge distance/timing, gravity, landing rules, and reaction state.

## Sword calibration gate

Sword is the first production combat animation benchmark.

A complete Sword package includes:

```text
Light 1
Light 2
Light 3
Light 4
Reprise
Heavy neutral
Heavy 1
Heavy 2
Heavy 3
Heavy 4
Dash Light
Dash Heavy
Aerial Light
Aerial Heavy
```

The semantic resolver maps the approved Sword gameplay graph onto these imported roles. Unapproved ground-combo families deliberately return no imported semantic and continue using procedural presentation.

## Material gate

Production Grace may remain a normal multi-material skinned mesh. She does not need to be split into the procedural proxy's many separate mesh nodes.

`GraceImportedMaterialEnroller` feeds semantic surfaces into the existing Character Material Presentation system.

Role priority:

1. explicit `character_material_surface_role_<index>` metadata;
2. explicit mesh-level `character_material_role` metadata;
3. exact recognized material names;
4. unresolved and reported for manual authoring.

Unknown materials are never guessed from partial names.

Material readiness requires:

- material director found;
- character root found;
- at least one semantic mesh/surface enrolled;
- zero unresolved imported surfaces.

## Playtest gate

`ready_for_character_playtest` means the asset is technically ready to compare against the procedural Grace. It does not mean the art is final.

The first local comparison should cover:

```text
idle
run / stop / reversal
jump / fall / land
dodge
Sword L1-L4
Sword Heavy branches
Dash Light / Heavy
Aerial Light / Heavy
two-handed support grip on a compatible weapon
hit / stagger response
```

Keep the procedural proxy available until the imported character survives those checks cleanly.

## Ownership boundary

Imported character assets and clips must not become authoritative for:

- movement physics;
- collision dimensions;
- attack timing or hit geometry;
- targeting or steering;
- combo graph progression;
- damage, stance, force, or status logic;
- weapon ownership;
- spell behavior.

Presentation expresses gameplay. It does not redefine it.
