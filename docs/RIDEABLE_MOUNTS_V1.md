# Rideable Mounts v1

Rideable Mounts v1 separates a mount's physical locomotion from the player's riding intent.

## Shared contract

A rideable exposes:

- a rider and saddle transform
- mount/dismount positions
- gait, velocity, turning, jumping, and mount stamina
- severe collision events
- summon, dismiss, and restore commands
- a small summon-contract dictionary for spell and UI consumers

This means a future summon spell only needs to acquire or create a rideable and call `summon_to()`. Horses, spectral beasts, carts, boats, and flying mounts can preserve the same rider-facing API while implementing different locomotion.

## Laboratory

Run:

`scenes/levels/prototypes/prototype_rideable_mount_lab_v1.tscn`

Controls:

- Interact: mount or dismount
- Move / left stick: throttle and steer
- Hold Guard: gallop while mount stamina remains
- Jump: leap when moving
- M: call the Courser to Grace
- N: dismiss or resummon it
- F8: reset

The course includes progressive fences, a slalom, a sprint lane, a severe-impact wall, and a summon-contract marker.

## Smoke test

`scenes/tests/rideable_mount_smoke_test.tscn`

The test validates installation, mounting authority, stamina drain, dismount cleanup, and the summon command contract.
