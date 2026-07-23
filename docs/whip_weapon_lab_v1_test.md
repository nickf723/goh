# Whip Weapon Laboratory v1

Run:

`scenes/levels/prototypes/prototype_whip_weapon_lab_v1.tscn`

## Contract

The Training Crackwhip is a separate weapon class built on the shared flexible-physics substrate. It reuses `FlexibleMaterialProfile`, `FlexibleTether3D`, and the generic runtime-rig hooks without inheriting the chain weapon's weighted-impact behavior.

During an attack, the whip rig:

1. Sends a visible wave front from the authored handle toward the tip.
2. Drives the endpoint through a readable snap, reverse snap, precision crack, overhead crack, or coiling trajectory.
3. Lets the shared leather tether solve the flexible body between those endpoints.
4. Samples local airflow so a light whip tail drifts in crosswind.
5. Records a swept tip path and checks contact only around that tip.
6. Scales damage from measured tip speed and adds sonic crack tags above the threshold.
7. Uses a generic post-hit callback to turn tagged wrap attacks into pull interactions.

The hybrid keeps attacks intentional while the visible flexible body, tip velocity, tension, airflow, and contact position remain physical.

## Controls

- `J` / left mouse / controller `L`: Light crack
- `K` / mouse side button / controller `R`: Heavy attack or combo branch
- `F8`: Reset the laboratory in editor builds

## Manual route

1. Stand still and confirm the leather whip hangs from Grace with visible slack.
2. Tap Light once. Confirm the bright wave ring travels outward and the violet tip sweeps across the snap lane.
3. Tap Light three times. Confirm Outward Snap, Returning Snap, and Needle Crack appear in the HUD.
4. Watch the tip-speed readout. Confirm the Crack indicator turns on when the tip crosses the displayed threshold.
5. Stand beside the broad sweep targets and confirm only targets touched by the tip path take damage.
6. Press Heavy from idle. Confirm Thunderclap follows a narrow overhead path and produces the strongest visible crack.
7. Press Light then Heavy while facing the pull ring. Confirm Coiling Catch latches briefly and the lever materially rotates to PULLED.
8. Press Light, Light, then Heavy. Confirm Reversal Snare catches from the opposite direction.
9. Move into the cyan crosswind zone. Confirm the HUD reports airflow and the light tail shifts sideways without moving Grace's authored handle.
10. Spend stamina on repeated Heavy attacks, wait 0.8 seconds, and confirm practice stamina regenerates at roughly 4 points per second.
11. Press F8. Confirm Grace, stamina, combo state, whip pose, targets, and the pull switch reset.

## Automated scene

`scenes/tests/whip_weapon_smoke_test.tscn`

It validates the six-node combo graph, tip-focused payload tags, leather material identity, runtime whip/tether construction, sonic crack threshold, pull-target contract, airflow station, and laboratory stamina regeneration.

## Deferred

- free-ended full-body wave propagation independent of authored tip intent
- persistent actor binding and dragging
- wrapping around arbitrary level geometry
- disarming and item retrieval
- collision along every flexible segment
- production Fire, Ice, and elemental-lash reactions
