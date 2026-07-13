# Actor Visual Wrapper Standard

## Goal

Allow characters and enemies to receive increasingly polished models without coupling art assets to gameplay behavior.

## Required hierarchy

```text
ActorGameplayRoot
├── CollisionShape3D
├── VisualRoot or imported visual scene
├── Camera / perception nodes
├── Interaction areas
├── Ability, weapon, and action controllers
├── Receivers and tags
└── Debug helpers
```

The gameplay root owns movement, collision, identity, and systems. The visual child owns appearance.

## Visual scene contract

A reusable actor visual scene should:

- use a `Node3D` root named for the visual, such as `GraceVisualV1`;
- contain no gameplay collision;
- contain no health, status, payload, or force receivers;
- contain no save or progression logic;
- use local origin at the actor's feet;
- face the same forward direction as the gameplay root;
- keep all model pieces below a child named `VisualRoot` when practical;
- expose optional markers for future VFX, head tracking, or hand alignment;
- remain safe to replace with an imported `.glb` wrapper later.

## Imported model wrapper

Future rigged models should use:

```text
GraceVisualProduction
├── Model                     imported GLB instance
├── AnimationTree
├── VFXAnchors
│   ├── Head
│   ├── LeftHand
│   ├── RightHand
│   ├── Chest
│   └── Feet
└── PresentationController
```

The imported model should not become the `CharacterBody3D` root.

## Scale and orientation

- Godot world unit: 1 meter.
- Visual feet rest at local `y = 0`.
- Character height must fit the existing collision before collision changes are proposed separately.
- Model forward must match the actor controller's forward convention.
- Do not rotate the gameplay root merely to fix an imported asset. Correct orientation inside the visual wrapper.

## Animation ownership

Animation may drive:

- bones;
- mesh deformation;
- cloth and accessory motion;
- local visual offsets;
- weapon presentation markers when coordinated with the weapon controller.

Animation must not silently drive:

- authoritative world movement;
- gameplay collision;
- damage timing;
- save position;
- receiver state.

Root motion requires a dedicated future gameplay decision.

## Debug visibility

The old capsule or debug mesh may remain hidden in the player scene during transition work. Developers can re-enable it temporarily when diagnosing scale or collision, but normal play should show only the art visual.

## Enemy extension

Enemy scenes should follow the same pattern:

```text
Enemy CharacterBody3D
├── CollisionShape3D
├── VisualRoot
├── Telegraph anchors
├── HitReceiver
├── StatusReceiver
├── PayloadReceiver
├── ForceReceiver
└── AI script
```

A polished enemy model should replace only `VisualRoot` unless the issue explicitly changes gameplay shape or attack timing.
