# Thermal Pressure v1 playtest

Run:

`scenes/levels/prototypes/prototype_thermal_pressure_lab_v1.tscn`

## Sequence

1. The boiler begins as liquid water at room temperature with zero stored pressure and the lift lowered.
2. Cast Firebolt twice into the left boiler. The water should become gas near 110 °C.
3. Watch the center gauge climb as the thermal adapter converts steam into the existing pressure reservoir.
4. At 55 pressure units, the right platform should rise.
5. Cast Ice Lance into the boiler. Steam should condense back to liquid, pressure should fall, and the platform should lower below 20 pressure units.
6. Reheat the boiler, then interact with the red center relief valve. Stored pressure should vent immediately.
7. Continue heating near the 90% safety threshold. The relief valve should automatically vent and the readout should show `AUTO-VENTING`.
8. Press F8 to restore cold water, zero pressure, a lowered lift, Firebolt selected, and full lab mana.

## Expected causal chain

`Fire → temperature → gas phase → pressure reservoir → mechanical actuator → lift motion`

Ice reverses the chain through condensation. The valve removes pressure directly without changing boiler temperature.

## V1 boundaries

- Pressure is a stable gameplay reservoir, not a spatial gas simulation.
- Steam generation scales with temperature above boiling.
- Condensation removes stored pressure at a tuned rate.
- The lift responds to pressure thresholds and does not model piston area or mechanical advantage.
- Automatic relief prevents pressure from remaining above the authored safety range.
- No explosions, pipe networks, fluid mass depletion, latent heat, turbines, or generators yet.
