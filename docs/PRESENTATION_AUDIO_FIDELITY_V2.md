# Presentation Audio Fidelity V2

## Why this pass exists

Grace's animation, combat grammar, camera contexts, material presentation, and semantic feedback systems have reached a point where the original procedural PCM cues are one of the clearest remaining prototype tells.

This pass upgrades the existing Presentation Director rather than creating a second sound architecture.

## Ownership

Gameplay remains authoritative for:

- attack timing
- damage and stance
- hit stop
- camera impact
- locomotion
- spell lifecycle
- material identity

Audio Fidelity V2 owns only:

- synthesized placeholder waveform quality
- harmless waveform variation
- material-specific footstep timbre
- weapon-motion whoosh/release timbre
- 3D playback through the existing semantic Director

A weapon swing sound must never change an attack timer, create hit stop, add a camera impulse, or decide whether an attack connected.

## Runtime chain

```text
gameplay fact
    ↓
PresentationService
    ↓
PresentationDirectorAudioFidelityV2
    ↓
PresentationAudioFidelityV2
    ↓
AudioStreamPlayer3D
```

`PresentationService` requires both spell and weapon-motion semantics before reusing a persistent Director, so hot-reload sessions cannot silently retain the pre-fidelity Director.

## Fidelity changes

The synthesizer now renders at 44.1 kHz instead of 22.05 kHz.

Each semantic cue rotates through four deterministic waveform variants. The semantic ID is stable, but transient noise, slight detuning, and resonant structure differ enough that repeated footsteps and impacts no longer sound like the exact same sample retriggered.

The V2 waveform combines:

- resonant partials
- colored noise
- a short transient layer
- a low body resonance
- cue-specific brightness
- cue-specific pitch sweep
- soft saturation

These are still production placeholders. Authored recordings can replace them later without changing any caller.

## Material footsteps

The Director now resolves a dedicated material footstep cue instead of layering the generic footstep over a full impact sound.

Current families:

- stone
- wood
- metal
- glass / crystal
- flesh / soft

Floor identity still comes from the existing material inference path.

## Weapon motion

`WeaponMotionAudioPresenter` listens to the existing `WeaponController.attack_started` signal.

It schedules the movement transient near the strike portion of startup rather than playing it immediately on button press. If the attack is cancelled or replaced before that point, the pending whoosh is discarded.

Current cue families:

- sword / general cutting motion
- axe
- staff
- fast weapons such as daggers and gauntlets
- heavy weapons such as hammer, mace, halberd, and scythe
- flexible weapons such as whip, chains, and flail
- bow release
- light thrown weapons such as shuriken and boomerang

Intensity derives from the already-authored attack definition and weapon class. It does not alter those values.

## Adaptive quiet HUD companion pass

The same global-presentation round adds `PlayerHUDAdaptiveQuiet` above the existing unified budgeted HUD.

No information is removed. During healthy exploration, persistent status, action, support, and activity surfaces recede through alpha only. They smoothly return when:

- combat begins
- Grace guards, dodges, casts, uses an item, or manipulates something
- lock-on is active
- a context prompt or activity appears
- health, stamina, or mana enters an alert range
- the player presses an action that benefits from command feedback

The goal is to make exploration read as the world first and the interface second, while keeping critical information immediately available.

## Tests

Focused regressions:

```text
res://scenes/tests/presentation_audio_fidelity_v2_smoke_test.tscn
res://scenes/tests/player_hud_adaptive_quiet_smoke_test.tscn
```

The presentation workflow also retains the existing Director, spell lifecycle, hit-reaction, Grace animation, and Polish Studio coverage.
