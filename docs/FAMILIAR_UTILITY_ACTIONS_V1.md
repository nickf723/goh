# Familiar Utility Actions v1

## Player flow

1. Summon a bonded familiar.
2. Select **Summon Familiar** and press Cast.
3. Choose **Go There**.
4. Aim at ordinary ground to issue the existing movement command.
5. Aim at a compatible task receiver to transform the same targeting prompt into a contextual utility action.

Examples:

- `HOLD PRESSURE PLATE`
- `RAM BARRICADE`
- `SEARCH BRUSH`

No separate utility wheel or controller binding is introduced.

## Runtime contracts

### FamiliarTaskReceiver

`res://scripts/summons/familiar_task_receiver.gd`

World objects declare:

- task identity and label
- required capability
- optional species restriction
- navigation anchor
- one-shot or sustained behavior
- affected/revealed world nodes
- optional item reward
- persistence key

Built-in v1 tasks:

- `hold`
- `ram`
- `forage`

### Familiar capabilities

`SummonedBondedAnimalFamiliar` exposes:

- `get_familiar_task_capabilities()`
- `has_familiar_task_capability(capability)`
- `issue_familiar_task(receiver)`
- `cancel_familiar_task(reason)`
- `get_familiar_task_state()`

All bonded animals can hold and forage in v1. Sheep, rams, goats, boars, and buffalo can ram. Species-specific capability expansion can remain data-driven.

### Task-aware targeting

`AbilityContextMenuTaskAware` preserves ordinary world targeting but asks the active provider for a target preview when a collider is present.

`PlayerSummonManager` resolves a `FamiliarTaskReceiver` from the collider ancestry. A compatible receiver replaces the Go There prompt and returns a task payload. Ordinary terrain continues to return a Vector3 movement payload.

### Persistent task state

`FamiliarTaskStateStore` writes one-shot outcomes to:

`user://goh_familiar_task_states_v1.json`

Completed barricades and forage discoveries therefore survive:

- familiar dismissal
- familiar resummoning
- receiver recreation
- scene reload
- application restart

Sustained tasks such as pressure plates are not persisted.

## Ruined Village route

The field-progression scene includes:

- Waykeeper Plate: sustained hold task that opens a gate
- Collapsed Timber: one-shot ram task
- Overgrown Herb Bed: one-shot forage task that reveals a cache and awards Life Bloom

## Regression

`res://scenes/tests/familiar_utility_actions_smoke_test.tscn`

The regression covers named Juniper summoning, capability filtering, task-aware target labels, hold cancellation, ram world consequences, forage rewards, dismissal/resummoning, and disk-backed completion restoration.
