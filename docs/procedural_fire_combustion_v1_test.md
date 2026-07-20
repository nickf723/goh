# Procedural Fire and Combustion v1

Run `res://scenes/levels/prototypes/prototype_element_vfx_gallery_v1.tscn`.

1. Visit the illuminated Fire wing on the left side of the gallery.
2. Compare the steady torch and larger bonfire. Confirm each uses changing flame silhouettes, smoke, embers, and flickering light rather than a static image.
3. Trigger Wind repeatedly. Confirm the wind specimen bends its flame and redirects smoke and embers with each airflow vector.
4. Trigger Burnout. Watch the low-fuel specimen shrink into smolder, consume its remaining fuel, and finish in the spent state.
5. Trigger Douse. The specimen should ignite, then lose its open flame after the cooling pulse and release a dying smoke plume.
6. Trigger Burst and cycle gallery intensity. Compare generated flame height, smoke, embers, light, and lifetime.
7. Cast Firebolt in a scene that equips it. Confirm the old sphere is hidden and the projectile carries a generated flame and ember trail while retaining its original movement and payload.
8. Toggle gallery slow motion to inspect flame curl, particle motion, and light flicker.
9. Press F8. Fire specimens, fuel, airflow, transient effects, counters, replay state, and global time should reset.

V1 intentionally defers wildfire-scale spread, oxygen simulation, structural collapse, persistent soot, room-filling smoke, liquid-fuel flow, and explosion chains.
