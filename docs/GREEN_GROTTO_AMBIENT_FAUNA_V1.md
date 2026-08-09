# Green Grotto Ambient Fauna v1

## Goal

Green Grotto already contains four procedural extinct-fauna visuals. Ambient Fauna v1 makes those creatures behave like background animals instead of endlessly looping the same circular patrol.

The behavior layer is presentation-only. It does not turn the art-target fauna into enemies, NPCs, navigation agents, encounter content, or persistent world actors.

## Integration

Each existing `GreenGrottoFaunaVisual` receives one child:

```text
AmbientBehavior
```

The base fauna visual remains responsible for mesh construction. Its old `animate_creature` loop is disabled once AmbientBehavior takes ownership of presentation motion.

This preserves a single transform/pose authority per creature.

## States

### Roam

The creature advances its authored patrol at a species-specific pace.

### Pause

Movement pauses while the head performs a slow environmental scan.

### Forage

The body settles and the head/neck lowers into a feeding-like pose.

### Curious

Raptors only. If Grace enters a medium-distance curiosity radius, the raptor stops patrolling and smoothly turns toward her.

### Startled

Raptors only. If Grace enters the closer personal-space radius, the raptor turns away and takes a small presentation-only retreat before settling back into its ambient cycle.

## Species language

Raptors use a faster behavioral clock, larger head scans, stronger tail response, and Grace proximity reactions.

The distant sauropod uses a slower roam / forage / pause cycle and deliberately ignores the raptor curiosity/startle contract. Its role is distant ecosystem life, not a reactive foreground NPC.

## Determinism

Ambient behavior timing is derived from each creature's existing `idle_phase` and elapsed time. It does not depend on random runtime rolls, so benchmark comparisons remain reproducible.

## Ownership boundary

Ambient Fauna may:

- move presentation-only fauna roots;
- pose existing head, tail, and visual-root pivots;
- read Grace's position for raptor curiosity/startle presentation;
- pause and resume authored patrol motion;
- give species different ambient behavioral rhythms.

Ambient Fauna must not:

- create combat or aggro state;
- use NavigationServer or pathfinding;
- apply damage or gameplay force;
- block progression;
- persist behavior state to saves;
- replace future production creature AI.

The v1 controller is explicitly a background-acting layer that can later be removed when authored animation/AI assets exist.

## Validation

```text
res://scenes/tests/green_grotto_fauna_ambient_behavior_smoke_test.tscn
```

The regression verifies:

- all four existing fauna visuals remain present;
- all four receive one ambient behavior component;
- the old perpetual animator is retired;
- a raptor becomes curious at medium Grace distance;
- a curious raptor visibly turns;
- close Grace proximity produces a short startled retreat;
- far raptors return to pause/forage beats;
- the sauropod never inherits raptor proximity behavior;
- the behavior layer owns neither navigation nor combat.
