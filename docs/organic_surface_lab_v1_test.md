# Seeded Organic Surface Lab v1 Manual Test

## Purpose

This permanent material laboratory isolates the reproducible surface workflow
behind Golden Meadow. It compares eight plots generated from one versioned
organic-ground recipe rather than judging the material inside a complete biome.

The first two plots are intentionally identical-seed twins. Their local pattern
must match even though the plots occupy different world coordinates. The other
six plots demonstrate bounded variation in patch placement, scale, dryness,
soil coverage, pebble coverage, and procedural relief.

## Load the laboratory

Run with F6:

```text
res://scenes/levels/prototypes/prototype_organic_surface_lab_v1.tscn
```

Controls:

```text
LEFT / RIGHT       SELECT PLOT
N                  NEXT SEED BANK
SPACE              REBUILD SELECTED PLOT
C                  COPY RECIPE SIGNATURE
Q / E              ORBIT CAMERA
W / S OR WHEEL     ZOOM CAMERA
R                  RESET CANONICAL BANK
```

## 1. Reproducibility proof

Compare **TWIN A** and **TWIN B** before changing anything.

Confirm:

- their seed numbers match;
- large dirt islands, turf breakup, pebble flecks, and fine relief line up in
  each plot's local coordinates;
- the readout reports `TWIN VERIFICATION PASS`;
- moving the camera does not make either pattern swim across its mesh.

Select either twin and press **SPACE** repeatedly. The selected material is
destroyed and rebuilt from the recipe. Confirm that its appearance does not
change and the readout reports `REBUILD PASS` every time.

## 2. Controlled variation

Select each of the six variation plots.

Confirm:

- each seed produces a recognizably different natural arrangement;
- every result still belongs to the same Golden Meadow material family;
- variation changes composition without producing implausible colors or
  extreme roughness;
- the selected gold frame and recipe readout always identify the inspected
  plot;
- the full signature changes when the seed changes.

Press **N** several times. Each bank should provide a new twin pair and six new
variations. Press **R** and confirm the original `18890417` twin pair returns.

## 3. Inspection lighting

Orbit with **Q/E** and zoom with **W/S** or the mouse wheel.

Confirm:

- the warm key reveals the procedural normal relief at grazing angles;
- the cool fill keeps shadowed turf and soil readable;
- ACES grading preserves bright earth and pebble highlights;
- the neutral plinth and background do not recolor the material family;
- all eight plots remain readable in the default framing.

## 4. Recipe handoff

Select a promising plot and press **C**. Paste the clipboard into a text editor.
The signature should contain:

```text
meadow_ground_seed_recipe_v1@v1:<seed>:<digest>
```

The source recipe is:

```text
res://data/environment_surfaces/meadow_ground_seed_recipe_v1.tres
```

Production assets should retain the recipe resource, generator version, seed,
and any deliberate parameter overrides. The digest is an inspection aid, not a
replacement for those source fields.

## Approval gate

Before adding another material family, decide:

1. Do the twins prove exact local-space repeatability?
2. Is the variation range broad enough to avoid obvious repetition?
3. Does every variation still read as the same authored location family?
4. Which seed produces the strongest balance of turf, soil, and close relief?
5. Should any variation range be narrowed before the recipe is reused?

## Automated validation

Registered smoke scene:

```text
res://scenes/tests/organic_surface_lab_smoke_test.tscn
```

It verifies the recipe, generator version, deterministic signatures, different
seed output, eight-plot bank, seven unique seeds, world-position-independent
twin match, same-seed rebuild, bank cycling, canonical reset, generated material
metadata, shader ownership, camera, UI, and inspection environment.

## Known limitations

- V1 contains one Golden Meadow ground recipe, not a general biome catalog.
- It varies the existing material procedurally; it does not bake texture files
  or export production assets.
- Generator math changes require a new `generator_version` before old recipes
  can be considered reproducible.
- Visual beauty, useful variation range, and the preferred production seed
  remain manual art-direction decisions.
