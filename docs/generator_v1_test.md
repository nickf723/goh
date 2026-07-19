# Generator v1 playtest

Run:

`scenes/levels/prototypes/prototype_generator_lab_v1.tscn`

1. Confirm the boiler begins liquid at room temperature, pressure is zero, the turbine is stopped, generated voltage is zero, and the circuit is open.
2. Cast Firebolt twice into the left boiler.
3. Watch steam create pressure, pressure accelerate the turbine, shaft RPM create voltage, and the circuit current rise.
4. Confirm the lamp turns on and the electromagnet attracts the iron puck.
5. Interact with the generator clutch while the turbine is spinning.
6. Confirm shaft RPM remains while voltage and circuit current fall to zero.
7. Interact again to reconnect the generator and restore electrical output.
8. Cast Ice Lance into the boiler.
9. Confirm steam condenses, pressure drains, the turbine coasts down, voltage disappears, and both electrical loads turn off.
10. Reheat the boiler and use the red relief valve to dump pressure without directly changing boiler temperature.
11. Press F8 and confirm water, pressure, shaft speed, coupling, circuit state, iron puck, player position, selected spell, and mana all reset.

Expected causal chain:

`Fire → heat → steam → pressure → turbine rotation → generator voltage → circuit current → light and magnetism`

Known v1 limits:

- Shaft speed is a scalar gameplay state rather than rigid-body rotational dynamics.
- The turbine uses authored pressure consumption and RPM curves.
- The generator uses authored voltage per RPM and does not yet model torque, electrical load drag, efficiency, or heat.
- The circuit solver still supports exactly one active voltage source and one lowest-resistance path.
- There is no AC waveform, frequency, transformer, commutator, turbine blade fluid simulation, or generator damage.
- The room is directly runnable and is not added to the central launcher registry.
