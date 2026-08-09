# Vegetation Presentation Director v1

## Goal

Vegetation Presentation Director makes procedural foliage respond to light like thin living material rather than solid plastic geometry.

It is a presentation-only material layer. It does not replace authored meshes, Environmental Motion, airflow physics, vegetation gameplay, or collision.

```text
VegetationPresentationProfile + semantic foliage material family
                              ↓
                 VegetationPresentationDirector3D
                              ↓
      shared two-sided / wrapped diffuse / backlit materials
```

## Core files

```text
scripts/vegetation/vegetation_presentation_profile.gd
scripts/vegetation/vegetation_presentation_director_3d.gd
```

## Shading vocabulary

Enhanced vegetation uses Godot's built-in `StandardMaterial3D` features:

- disabled culling for two-sided leaf forms;
- Lambert-wrap diffuse shading;
- backlight for cheap thin-surface light transport;
- restrained subsurface scattering and transmittance;
- procedural `NoiseTexture2D` normal breakup;
- world-space triplanar mapping so stretched procedural leaf meshes do not advertise their primitive UVs;
- role-specific roughness.

No custom vegetation shader is required in v1.

## Role tiers

### Ground foliage

Ferns, cycads, and low foliage receive moderate green backlight, restrained SSS/transmittance, and close-range normal detail.

### Sunlit foliage

Foliage already authored as sun-facing receives stronger yellow-green backlight and transmittance so the Green Grotto sunset can illuminate thin edges and fronds.

### Canopy

The canopy uses the cheapest tier. Backlight does most of the work and SSS is intentionally much weaker because the canopy covers large screen areas.

## Green Grotto integration

Profile:

```text
data/vegetation/green_grotto_vegetation_presentation.tres
```

Integration:

```text
scripts/levels/prototype_green_grotto_vegetation_pass.gd
```

The pass discovers vegetation by the existing semantic material families:

```text
foliage         -> ground
foliage_sunlit  -> sunlit
canopy          -> canopy
```

It does not depend on mesh names. Replacement assets can inherit the same presentation simply by continuing to use the semantic material family.

## Shared-resource rule

Do not create one enhanced material per frond.

The Director caches by original material + role. In Green this resolves the entire enrolled vegetation set to three shared enhanced materials and three generated normal textures.

## Ownership boundary

Vegetation Presentation may:

- swap presentation materials;
- change culling and diffuse mode;
- add backlighting/transmission;
- add procedural surface normal detail;
- change visual roughness.

It must not:

- move foliage transforms;
- create wind or force;
- move collision;
- change traversal or stealth gameplay;
- own plant simulation or growth;
- change water, rock, masonry, fauna, or Grace materials.

Environmental Motion remains responsible for cluster sway. Airflow remains responsible for gameplay wind. The two systems are intentionally independent.

## Benchmark hotkeys

Green Grotto now exposes the full presentation ladder:

```text
F1  Vegetation Presentation ON/OFF
F2  Water Presentation ON/OFF
F3  Material Fidelity ON/OFF
F4  Surface Story ON/OFF
F5  Environmental Motion ON/OFF
F6  Camera Director ON/OFF
F7  Lighting quality tier
```

F1 restores the exact original foliage material resources. It never rebuilds meshes or modifies foliage transforms.

## Validation

```text
res://scenes/tests/vegetation_presentation_director_smoke_test.tscn
```

The regression verifies:

- dense Green foliage enrollment;
- ground, sunlit, and canopy role coverage;
- exactly three shared enhanced material families;
- exactly three generated normal textures;
- two-sided wrapped diffuse shading;
- backlight and restrained SSS/transmittance;
- cheaper canopy SSS than close foliage;
- world-space triplanar detail;
- exact F1 material restoration without mesh/transform changes;
- independence from Environmental Motion, Water Presentation, and Material Fidelity.
