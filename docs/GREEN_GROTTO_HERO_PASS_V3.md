# Green Grotto V3 Hero Pass

The V3 pass is the first Green Earth environment layer that deliberately replaces visible prototype geometry instead of decorating it.

## Scene

```text
res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn
```

The scene now resolves through:

```text
PrototypeGreenGrottoArtTarget
  -> PrototypeGreenGrottoDetailPass
    -> PrototypeGreenGrottoHeroPass
      -> PrototypeGreenGrottoHeroSurfaceFinish
```

The earlier layers still own composition and stable collision. V3 hides broad prototype meshes where it provides a visible replacement.

## Water contract

V3 completely retires every child under the legacy `GreenGrottoArt/Water` root after the earlier passes finish building.

The replacement is:

```text
GreenGrottoArt/HeroPassV3/HeroWater
  V3UpperStream
  V3UpperStreamBed
  V3WaterfallSheet00..03
  V3LowerBasin
  V3UpperBank*
  V3LowerBank*
  V3LipFoam*
```

The upper stream and lower basin are irregular `ArrayMesh` polygon surfaces. There is no broad horizontal water box beneath the level. Water is now localized to an upper source, narrow fall, and lower basin.

## Geometry promotion

V3 hides the visible meshes on the broad arrival shelf, major cliff boxes, causeway slabs, side terraces, broken ledge, back mountain, and shrine foundation while retaining their collision.

Visible replacements include:

- dense layered rock masses and chasm shelves;
- exposed causeway masonry faces and ruined support piers;
- fitted hero paving and wet paving;
- sparse broken causeway railings;
- individual shrine foundation masonry courses;
- stronger bracket/eave construction rhythm;
- layered roof battens and finials;
- broken shrine terrace railings;
- tiled side terraces and complete masonry skirts;
- tiled shrine deck and localized moss accumulation;
- large ecological foliage pockets and framing roots.

## Lighting direction

The sunset remains the warm key, but V3 reduces orange fog/exposure and increases cool green ambient/fill light. The goal is warm shafts against readable green shadow rather than a uniform brown-orange wash.

## Art-production boundary

V3 is still procedural geometry and material work. It exists to establish:

- composition;
- scale;
- collision-safe visible replacement seams;
- water geography;
- material families;
- environmental density;
- Chinese-inspired shrine construction language;
- ecological clustering.

Imported production meshes and textures can later replace V3 families without changing the gameplay shell.

Production spell VFX and final audio remain intentionally deferred while the environment art target is being established.
