# Player Preferences and Accessibility v1

## Purpose

The Field Kit's System tab previously described controls and promised settings later. Player Preferences v1 turns that placeholder into a small live configuration layer while preserving every existing default.

The first pass focuses on camera comfort and motion feedback because those settings can be applied safely across Grace, Divine Incarnations, and future playable avatars without changing combat balance.

## Persistence scope

Preferences are stored at:

```text
user://goh_player_preferences.json
```

They are **user-profile settings**, not Grace's save-slot progression.

Starting a new journey, resetting GameState, changing save beds, or loading an older adventure does not reset camera and motion preferences. The preference file is versioned independently so later options can be added without changing the game-save schema.

## Shared player integration

Every standard player now owns:

```text
Player/PlayerPreferences
```

The service captures the authored defaults already present on the shared player and applies user-selected multipliers to those values. It does not replace the player controller, weapon controller, motion rig, or camera.

Current live targets are:

```text
PlayerController camera exports
WeaponController camera impact
PlayerMotionFeedback procedural effects and landing impulse
```

Divine Incarnation retains the same stable Player anchor, so Ruvia and future incarnated gods automatically inherit the same user preferences.

## Current settings

### Camera Input

| Setting | Values | Default |
| --- | --- | --- |
| Mouse Look Speed | 50%, 75%, 100%, 125%, 150%, 200% | 100% |
| Controller Look Speed | 50%, 75%, 100%, 125%, 150%, 200% | 100% |
| Camera Stick Deadzone | Small, Default, Large, Extra Large | Default |
| Camera During Focus Menu | Locked, Enabled | Locked |

### Motion and Feedback

| Setting | Values | Default |
| --- | --- | --- |
| Camera Impact | Off, Reduced, Full | Full |
| Motion Pulses | Off, Reduced, Full | Full |

Camera Impact currently scales the camera offsets used by weapon contact and landing feedback. It never changes damage, hit stop, attack timing, invulnerability, movement, or landing classification.

Motion Pulses scale the procedural rings and motes used for footsteps, takeoff, landing, and climbing grip feedback. Turning them off does not disable the underlying movement signals.

## Field Kit integration

Open the Field Kit with:

```text
Tab or M
```

Choose **System**. The tab now displays:

- profile-wide persistence scope;
- the number of changed and default settings;
- Camera Input settings;
- Motion and Feedback settings;
- one Restore Defaults action.

Select a setting to cycle to its next authored value. Changes apply immediately and are automatically written to the preference file.

The menu continues to pause gameplay while open. Returning to gameplay uses the newly selected values without requiring a scene reload.

## Architecture

```text
scripts/settings/player_preference_service.gd
scripts/ui/full_menu_shell_settings.gd
scripts/visuals/player_motion_feedback.gd
scenes/actors/player/player.tscn
```

`PlayerPreferenceService` owns definitions, normalization, cycling, snapshots, JSON storage, live application, and diagnostics.

`FullMenuShellSettings` extends the existing Journal, Codex, inventory, and spellcasting-mastery menu stack. It replaces only the System-tab placeholder and forwards every unrelated action to the established menu implementation.

`PlayerMotionFeedback` exposes separate visual-effect and camera-impulse scales. Preference changes adjust presentation while leaving footstep, jump, landing, and motion-state signals intact.

## Automated validation

Run in Godot:

```text
scenes/tests/player_preferences_smoke_test.tscn
```

Expected Output-panel marker:

```text
PLAYER_PREFERENCES_SMOKE_TEST: PASS
```

The regression checks:

- installation on the shared player;
- six authored settings and user-profile scope;
- unchanged authored defaults;
- mouse and controller sensitivity application;
- right-stick deadzone normalization;
- Focus-menu camera control;
- weapon and landing camera-impact scaling;
- motion-effect scaling;
- snapshot restoration;
- forward and reverse option cycling;
- live System-tab rendering;
- System-tab action routing and reset coverage.

The test disables automatic disk writes and restores the preference snapshot it found before exiting.

## Manual test in Godot

1. Run any level that uses the standard player and Game UI.
2. Open the Field Kit with `Tab` or `M`.
3. Select **System**.
4. Confirm all six settings and **Restore Defaults** appear.
5. Raise and lower Mouse Look Speed, close the menu, and move the mouse.
6. Repeat with Controller Look Speed and the right stick.
7. Change Camera Stick Deadzone and test small stick movements.
8. Enable Camera During Focus Menu, open the spell Focus menu, and move the right stick.
9. Set Camera Impact to Off, then land from a height and connect a sword attack.
10. Set Camera Impact to Reduced and compare the same actions.
11. Set Motion Pulses to Off and inspect footsteps, takeoff, landing, and climbing.
12. Restore Motion Pulses to Full.
13. Choose **Restore Defaults** and confirm every tile returns to its default badge.
14. Restart the project and confirm the chosen settings return.
15. Start or reset a run and confirm the preferences remain unchanged.
16. Press `F9` in a debug build and confirm Ruvia inherits the same camera and motion settings.

## Deliberate boundaries

The first pass does not yet include:

- camera-axis inversion;
- input rebinding;
- hold-versus-toggle options;
- subtitle size, background, or speaker labeling;
- global UI scaling;
- color-vision filters or high-contrast targeting;
- flash reduction across elemental VFX;
- audio volume and dynamic-range controls;
- controller vibration settings;
- separate per-save preference profiles.

Those options should extend this service rather than creating another settings database.
