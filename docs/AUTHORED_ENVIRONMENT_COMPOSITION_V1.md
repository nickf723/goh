# Authored Environment Composition v1

The authored environment composition layer turns replacement-ready primitive geometry into coherent prototype spaces without pretending that layout, mood, or art direction can be automated.

## Division of responsibility

The reusable layer owns:

- collision-matched architectural primitives;
- palette-driven prototype materials;
- continuous floors and walls;
- stair runs, pillars, archways, benches, local lights, and visual landmarks;
- consistent metadata for environment auditing;
- reusable checks for missing collision and malformed stair runs.

The level-specific pass owns:

- floor plan and circulation;
- sightlines and landmarks;
- story staging;
- prop placement;
- lighting composition;
- environmental history;
- how obvious or mysterious a route should feel.

This avoids both extremes: every level hand-forging the same BoxMesh helpers, or a universal room generator deciding what an abandoned chapel should mean.

## Shared owners

```text
scripts/environment/authored_environment_palette.gd
scripts/environment/authored_environment_builder.gd
scripts/environment/authored_environment_auditor.gd
```

`AuthoredEnvironmentPalette` centralizes prototype material identity. `AuthoredEnvironmentBuilder` creates matched visual and collision geometry plus reusable architectural assemblies. `AuthoredEnvironmentAuditor` checks the objective contracts that can be verified mechanically.

## Builder assemblies

The v1 builder supports:

- static boxes and cylinders with matched collision;
- visual boxes, cylinders, spheres, and torus forms;
- continuous stair runs;
- pillars;
- archways;
- non-blocking bench dressing;
- local point lights;
- material caching and palette lookup;
- build statistics for focused regression tests.

New assemblies should be added only when at least two authored spaces need the same structural pattern. A one-off altar, bell frame, or village facade belongs in its level pass until repetition proves otherwise.

## Drowned Chapel reference

```text
scripts/levels/drowned_bell_environment_pass.gd
data/environment_palettes/drowned_chapel_palette.tres
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
```

The chapel pass uses the shared builder but keeps its actual layout authored. It replaces the former slab collection with a continuous causeway, nave, west memorial aisle, flooded side chapel, raised altar, crypt frame, bell frame, rose window, pews, rafters, overgrowth, and composed lighting.

## Environment quality gate

Before adding another story beat to an authored space:

1. The golden path must have continuous supporting collision.
2. Visible architecture must meet neighboring surfaces without accidental gaps.
3. Water must have a readable physical entrance and at least two exits.
4. Required props must have a recognizable silhouette without relying only on labels.
5. Major landmarks should be visible before the player reaches them.
6. Decorative props must not narrow the required route or create snag points.
7. Camera movement must remain usable beside walls, pillars, and doorways.
8. The authored environment auditor and global playability auditor must pass.
9. The route must be completed without Blink, Flight, or recovery intervention.
10. A human playtest remains the final authority on composition and clarity.

The builder is scaffolding for authored work, not a vending machine for finished levels.
