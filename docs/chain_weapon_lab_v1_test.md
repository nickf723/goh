# Chain Weapon Laboratory v1

Run:

`scenes/levels/prototypes/prototype_chain_weapon_lab_v1.tscn`

## Contract

The Training Meteor Chain remains a normal data-driven weapon: its attack definitions choose timing, combo branches, payload tags, and authored intent. Its `runtime_rig_scene` adds the flexible presentation and contact behavior.

During an attack, the rig:

1. Moves the weighted tip through the attack's authored orbit or slam trajectory.
2. Feeds the moving endpoints into the shared `FlexibleTether3D` iron-chain simulation.
3. Records the full startup sweep rather than checking only the final frame.
4. Queries payload receivers along that swept path.
5. Scales stance and knockback modestly from measured tip momentum.
6. Sends the resulting `DamagePayload` through the existing receiver grammar.

The controller hook is generic. A future whip, flail, or living tendril may provide its own runtime rig without adding another weapon-specific branch to `WeaponController`.

## Controls

- `J` / left mouse: Light orbit
- `K` / controller right shoulder: Heavy branch
- `F8`: Reset the laboratory in editor builds

## Manual route

1. Stand at the starting marker without attacking. Confirm the chain hangs with visible slack and follows Grace.
2. Tap Light once. Confirm the meteor sweeps through the left, center, and right orbit targets.
3. Tap Light three times with deliberate timing. Confirm the HUD reports Outward Orbit, Returning Orbit, then Rising Recall.
4. Press Heavy from idle. Confirm Meteor Drop travels overhead and down the narrow center line.
5. Press Light then Heavy. Confirm Orbit Breaker replaces the second light attack.
6. Press Light, Light, then Heavy. Confirm Reversal Breaker uses the opposite sweep direction.
7. Press Light three times, then Heavy. Confirm Cathedral Meteor is the slowest and most committed finisher.
8. Watch the HUD during attacks. Tip speed, momentum, tension, phase, and buffered input should update live.
9. Stand just outside the glowing tip path. Confirm the chain does not hit merely because a target is inside a broad character-centered cone.
10. Press F8. Confirm Grace, stamina, combo state, chain pose, and all training targets reset.

## Automated scene

`scenes/tests/chain_weapon_smoke_test.tscn`

It validates the chain resource identity, seven-node combo graph, payload tags, runtime rig construction, shared flexible tether, and laboratory instantiation.

## Deferred

- wrapping around level geometry
- persistent latching and pulling
- binding actors
- chain-versus-chain contact
- dedicated enemy reactions to entanglement
- elemental conduction during combat
- whip wave propagation
