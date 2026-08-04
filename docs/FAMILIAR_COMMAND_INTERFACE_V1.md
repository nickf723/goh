# Familiar Command Interface v1

## Purpose

Familiar commands now belong to the Summon Familiar spell lifecycle rather than to level-specific animal panels.

The player always owns a `PlayerSummonManager`, but the familiar command UI remains hidden until that manager emits `summon_created`. Dismissing or losing the familiar immediately closes every command surface and removes its status card.

## Controller grammar

- Hold **L3** to open the familiar command wheel.
- Use the **right stick** to select a command.
- Release **L3** to issue the highlighted command.
- Press **B** to cancel without changing the active command.
- Selecting **Go There** enters aimed world targeting.
- Press **A** to confirm the destination.
- Press **B** to cancel destination targeting.

Keyboard and mouse fallback:

- Hold **F** to open the command wheel.
- Release **F** to issue the highlighted command.
- Enter or left click confirms Go There.
- Escape or right click cancels.

The command wheel uses the shared focus-menu action lock and modestly slows time while open. Ordinary time and controls are restored on command, cancellation, dismissal, or scene cleanup.

## Lifecycle

`FamiliarCommandInterface` is installed by `PlayerSummonManager` beneath the player actor.

Before summoning:

- The compact familiar card is hidden.
- The radial command surface is unavailable.
- Go There targeting is unavailable.

After Summon Familiar succeeds:

- The compact card appears with the familiar name and current command.
- The command wheel is populated from the active familiar's capabilities.
- Unsupported commands are omitted rather than displayed as disabled duplicates.

After dismissal or defeat:

- The compact card disappears.
- Open radial or targeting surfaces close.
- World-time and player-action locks are restored.

## Unified command contract

The summon manager no longer requires every summon scene to inherit `SpectralFamiliar`. A summon scene must be a `Node3D` and implement:

`initialize(owner, manager)`

Optional familiar capabilities include:

- `get_available_familiar_commands()`
- `get_familiar_command_data()`
- `issue_follow_command()`
- `issue_stay_command(anchor)`
- `issue_come_here_command()`
- `issue_move_to_command(destination)`
- `set_command(command)` for legacy combat familiars
- `configure_familiar(loadout, definition)`
- `dismiss_familiar()`
- `familiar_defeated` signal

`PlayerSummonManager.issue_familiar_command()` translates the UI command IDs into whichever supported capability the active familiar provides.

## Animal familiar adapter

`SummonedBondedAnimalFamiliar` extends the navigation-aware bonded animal actor and supplies the summon contract.

It exposes the animal command set:

- Follow
- Stay Here
- Come Here
- Go There

The adapter deliberately omits combat-only commands such as Assist and Focus Target unless a later animal type explicitly supports them. It preserves the authoritative command behavior already validated by the wildlife lab, including immediate Stay cancellation, anchor ownership, destination movement, and fear-aware command state.

## Existing spectral familiars

Legacy spectral and Gremlin familiars continue to summon through the same manager. Their available command set is inferred from their existing command methods. This keeps current combat familiar behavior working while allowing bonded animals to use the more physical navigation command grammar.

## Automated validation

Run:

`res://scenes/tests/familiar_command_interface_smoke_test.tscn`

Expected output:

`FAMILIAR_COMMAND_INTERFACE_SMOKE_TEST: PASS`

The test verifies:

- The UI is hidden before summoning.
- The player installs the command interface automatically.
- L3, A, and B controller bindings exist.
- A bonded animal adapter can be created through `summon_familiar()`.
- The UI appears only after the summon is created.
- Animal commands are capability-filtered.
- Controller press, selection, release, and cancellation behavior.
- The shared action lock and time slowdown are restored correctly.
- Stay reaches the authoritative animal command layer.
- Go There enters targeting and preserves the confirmed world destination.
- Dismissal removes all familiar command UI.
