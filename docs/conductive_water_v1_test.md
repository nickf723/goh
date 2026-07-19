# Conductive Water v1 manual test

Run `scenes/levels/prototypes/prototype_conductive_water_lab_v1.tscn`.

1. Confirm the lab starts with Lightning Spark equipped and the water basin filled.
2. Leave the source selector on Battery. The circuit should be closed through the water, with the lamp and electromagnet powered.
3. Use the center Water Control console to drain the basin. The water mesh should disappear and the circuit should open.
4. Fill the basin again. The battery circuit should close without moving any objects.
5. Use the left source selector to choose Lightning to Water. The circuit should become open while the water waits for excitation.
6. Cast Lightning Spark into the pool. The pool should brighten, report ELECTRIFIED, flash the lamp, and pulse the electromagnet.
7. Trigger the storm console. Environmental Lightning should electrify the same pool and power the same circuit.
8. Switch to Firebolt and cast into the pool. Fire should not power the circuit.
9. Press F8 and confirm the basin returns filled, normal, and battery-powered.

Known v1 limits:
- One water volume connects two immersed electrodes.
- Water resistance is a stable gameplay approximation based on electrode distance and conductivity.
- No branching current through three or more electrodes.
- No fluid flow, buoyancy, freezing, boiling, salinity simulation, or resistive heating yet.
