# Thermal State v1 manual test

Run `scenes/levels/prototypes/prototype_thermal_state_lab_v1.tscn`.

1. Use Firebolt on either copper block. Its temperature should rise, then heat should gradually transfer into the touching block.
2. Use Ice Lance on either block. Its temperature should fall and the temperature difference should again decay through contact.
3. Observe the center water circuit at room temperature. Liquid water should close the loop and illuminate the lamp.
4. Cast Ice Lance into the water. It should become solid and the circuit should open.
5. Cast Firebolt once into the frozen water. It should thaw and restore the circuit.
6. Continue casting Firebolt until the water becomes gas. The liquid path should disappear and the circuit should open again.
7. Observe the right resistor. Solved current should continuously increase its temperature through resistive heating.
8. Use Ice Lance on the resistor and confirm spell cooling and electrical heating compete through the same temperature state.
9. Press F8. Temperatures, phases, circuits, player position, and spell resources should return to their initial state.

Expected spell slots: `1` Firebolt, `2` Ice Lance.

V1 intentionally omits latent heat, convection, fluid motion, pressure, material deformation, large-scale fire propagation, and player body-temperature effects.
