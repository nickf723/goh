# Presentation Director v1

## Goal

Turn gameplay facts into one shared sensory language instead of letting every spell, weapon, prop, and movement controller hand-author its own unrelated feedback stack.

```text
gameplay event
    ↓
Presentation Director
    ├─ contact / reaction audio
    ├─ elemental audio accent
    ├─ haptic preset
    ├─ reaction VFX
    ├─ camera impulse
    └─ hit stop when the owning gameplay system does not already provide it
```

The Director is installed lazily under the SceneTree root by `PresentationService`, so it survives level transitions without becoming another project autoload.

## Semantic events

The first pass supports:

- `impact`
- `reaction`
- `break`
- `footstep`
- `jump`
- `landing`

The event record is intentionally presentation-facing. Gameplay remains authoritative for damage, stance, physics, statuses, and reaction resolution.

## Impact identity

An impact can carry:

- target
- world position
- material
- element
- damage / stance intensity
- result metadata
- critical / defeated / resisted state

Material inference currently understands:

- metal
- stone
- wood
- glass / crystal
- flesh
- soft fallback

Sources include explicit presentation metadata, `get_presentation_material()`, gameplay `TagComponent` tags, presentation material groups, names, and enemy/body fallback.

## Layer ownership

Weapon melee already owns authored hit stop and camera impact in `WeaponController`. The Director therefore adds contact texture, haptics, reaction audio, and reaction VFX to melee without applying a second large temporal/camera response.

Non-weapon reactions can request the Director's shared hit-stop and camera layer.

This is the core anti-double-feedback rule for future integrations: a semantic event may have many presentation listeners, but each channel must have one clear owner.

## Audio prototype

`PresentationAudio` currently synthesizes short 3D PCM cues in code. These are tuning placeholders, not final sound assets.

The prototype gives us immediately distinguishable families for:

- wood / stone / metal / glass / flesh contact
- resist / stagger / launch / guard break
- footsteps / jumping / landing
- wood / stone / metal / glass destruction
- Fire / Water / Ice / Lightning / Life / Death / Space / Sound accents

Each cue ID is the stable interface. Authored WAV/OGG assets can later replace the synthesized stream behind a cue without changing gameplay callers.

Temporary AudioStreamPlayer3D instances are tracked through weak references and capped so presentation cannot retain dead scene objects indefinitely.

## Haptics

`GameFeedback` now includes a presentation hierarchy:

- light impact
- medium impact
- resisted impact
- stagger
- launch
- guard break
- object break
- landing

These sit beside the existing charge, guard, player-hit, and warning presets.

## Movement

`PlayerMotionFeedback` now sends footsteps, jump starts, and landings through the same Director while retaining its existing procedural rings and landing camera response.

Floor material is sampled downward from Grace at the event position, so the same locomotion can acquire different contact texture without rewriting the movement controller.

## Breakables

`BreakableProp` now reports destruction through the Director. Existing TagComponent material tags such as `wood` are reused rather than creating a second material database.

## Safe telemetry

Presentation history never stores live Node or Resource references. Semantic events are sanitized into names, instance IDs, resource paths, vectors, numbers, strings, and nested data before being cached or emitted through the Director's telemetry signal.

This prevents a destroyed target or prop from leaving a stale object reference inside the presentation debugger.

## Polish Studio

Run:

```text
res://scenes/levels/prototypes/prototype_polish_studio_v1.tscn
```

The room contains:

- wood, stone, metal, and glass footstep strips
- light, armored, and super-armored reaction targets
- wood, stone, metal, and glass breakables
- normal Grace spell / weapon controls
- a live semantic-event telemetry panel

Controls:

- normal movement / combat / spell controls
- `F5`: cycle a deterministic material + reaction + element preview
- `F8`: reset the studio

## Regression

```text
res://scenes/tests/presentation_director_smoke_test.tscn
```

The focused regression checks:

- one persistent Director service
- procedural PCM generation and caching
- material inference from gameplay tags
- contact + elemental audio layering
- object-free telemetry
- weapon ownership of melee hit stop / camera response
- shared breakable material presentation
- bounded semantic event history

The dedicated GitHub workflow also cold-imports the project, boots the Polish Studio, and reruns hit-reaction and Grace-animation regressions.
