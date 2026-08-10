# Green Earth Foundation Shell v0.1

## Purpose

The Green Earth calibration kit answers **reusable asset** questions. The foundation shell answers a different question:

> What continuous physical place do those reusable pieces belong to?

The shell exists so path slabs, cliffs, shrine modules, water, and Grace no longer read as isolated objects suspended in an empty scene.

It inherits the global art bible and environment-production contract, but it is intentionally **not** another reusable kit.

```text
GLOBAL ART BIBLE
    ↓
UNIQUE WORLD SHELL
    ↓
REUSABLE ENVIRONMENT KIT
    ↓
DRESSING / LIGHTING / VFX
```

---

# Boundary

The Green foundation shell owns broad visual continuity only:

- basin floor;
- continuous canyon water;
- arrival landmass;
- lower canyon underfill beneath modular cliff silhouettes;
- shrine island / approach apron;
- rear canyon closure.

It does **not** own:

- gameplay collision;
- repeated cliff assets;
- path slabs;
- shrine columns, roof, beams, brackets, or lanterns;
- foliage kit pieces;
- final sculpted geology;
- decorative rubble;
- particle atmosphere.

The existing hidden Green Grotto blockout remains authoritative for collision and traversal.

---

# v0.1 Composition

```text
rear canyon closure
██████████████████████████
          shrine
       [kit modules]
       ███████████
       shrine island
~~~~~~~~~~ water ~~~~~~~~~~
      path kit slabs
~~~~~~~~~~ water ~~~~~~~~~~
██ canyon feet   canyon feet ██
        arrival bank
            Grace
```

The visual shell is intentionally broad. It should make the scene feel physically continuous even while every reusable module is still an obvious placeholder.

---

# Shell Pieces

## BasinFloor

A broad dark lower substrate beneath the entire study set.

Purpose:
- establish a physical bottom;
- remove the impression of infinite void beneath transparent water;
- give the canyon depth.

## BasinChannelShelf

A slightly raised wet-rock mass beneath the main water corridor.

Purpose:
- create subtle depth variation under water;
- avoid one featureless dark basin rectangle;
- remain well below traversable surfaces.

## CanyonWaterBody

One continuous water body running through the canyon.

Waterline:

```text
approximately y = -0.3425 m
```

The calibration path slabs remain clearly above it.

The single large surface is deliberate at this stage. Shoreline breakup belongs to later authored shell art, not a swarm of procedural water fragments.

## ArrivalBank

A broad land mass beneath the spawn / arrival area.

Its top aligns with the original authored blockout ground plane so Grace begins on visibly continuous terrain before stepping onto the route.

## ArrivalWetShoulders

Two low broad side masses transition the arrival land into the water corridor.

They are large forms, not decorative rocks.

## CanyonFootNear / CanyonFootDeep

Four lower canyon underfill masses connect the reusable calibration cliff modules to the basin.

This solves a key hierarchy problem:

```text
WORLD SHELL = geological continuity
CLIFF MODULE = reusable silhouette / authored rock language
```

A future Blender cliff asset should not be responsible for secretly building the whole canyon underneath itself.

## ShrineIslandCore

A broad raised geological island beneath the shrine kit.

Its top aligns with the shrine platform's ground pivot, making the architecture visibly built on land rather than floating over water.

## ShrineApproachApron

A quiet broad masonry transition between the final stepping route and shrine stair.

It belongs to the unique composition and should not compete with the reusable shrine kit.

## RearCanyonClosure / Returns

Three large forms close the finite benchmark environment behind the shrine and around camera rotation angles.

Their job is not detail. Their job is to eliminate raw horizon / void reads and reinforce canyon enclosure.

---

# Art Direction Rules

## 1. The shell stays quieter than the kit landmark

Large shell surfaces should support composition without becoming the most detailed thing on screen.

## 2. World continuity before dressing

Do not add small rocks, vines, decals, particles, or debris to solve gaps that should be solved by the shell itself.

## 3. Unique shell, reusable kit

A shrine column can repeat. A canyon basin probably should not.

If a shape exists primarily because of this exact level's geography, it belongs to the shell or bespoke level art.

## 4. Collision remains independent during calibration

The shell is visual-only. The proven blockout keeps gameplay stable while art proportions change.

## 5. Concept art remains the target

The current Godot shell is a spatial placeholder. Final terrain continuity should eventually come from authored environment meshes, likely created in Blender and imported through stable scene seams.

---

# Success Criteria

The shell passes v0.1 when the scene reads, even with crude calibration modules, as:

- one canyon rather than objects in a void;
- stepping stones crossing water;
- cliffs rising from a continuous basin;
- a shrine anchored to its own island;
- a finite but convincing enclosed environment;
- clear Grace → route → shrine composition.

It does **not** need to look finished.

---

# Next Art Step

After shell scale and waterline are approved, begin replacing the five highest-value Green calibration modules with authored meshes:

1. `green_cliff_a`
2. `green_path_slab_a`
3. `green_shrine_column`
4. `green_shrine_roof`
5. `green_fern_cluster`

The shell should then evolve around those approved forms rather than accumulating procedural detail.
