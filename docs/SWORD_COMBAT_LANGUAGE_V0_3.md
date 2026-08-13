# Sword Combat Language v0.3

## Goal

This pass polishes the individual Sword combo beats after the skeletal animation pipeline made combat readable enough to judge motion quality directly.

The target is a hybrid combat language:

- committed, readable Light / Heavy fundamentals;
- branching combo depth similar to a crowd-action combo tree;
- exaggerated silhouettes without turning ordinary attacks into full-body windmills;
- explicit context attacks for dodge and jump states.

The pass does not copy animation from another game. It defines Grace of Humanity's own timing, geometry, and skeletal working envelope.

Primary playtest scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

## Ground Sword grammar

The Sword now has a clear Light-depth tree:

```text
L1 Opening Cut
  ├─ Light → L2 Returning Cut
  └─ Heavy → H1 Rising Break

L2 Returning Cut
  ├─ Light → L3 Rising Cut
  └─ Heavy → H2 Crowd Cleave

L3 Rising Cut
  ├─ Light → L4 Circular Cut
  └─ Heavy → H3 Driving Thrust

L4 Circular Cut
  ├─ Light → Reprise Thrust
  └─ Heavy → H4 Orbit Finisher
```

Neutral Heavy remains:

```text
H0 Guardbreaker
```

and may flow into Reprise Thrust.

The previous resource accidentally assigned `next_light_attack_id` twice on several Light attacks. The second assignment routed those beats into Reprise instead of the apparent L1 → L2 → L3 → L4 chain. v0.3 removes the duplicate assignments and makes the branch tree explicit.

## Motion-envelope rule

Ordinary Sword attacks should remain inside Grace's **working envelope**.

That means:

- windups load beside / slightly across the body rather than behind the back;
- normal Light contacts stay in front of Grace;
- follow-through may cross the silhouette but should brake before becoming a full spin;
- thrusts keep the blade close to level;
- rising attacks use a diagonal lift rather than a giant vertical scoop;
- Heavy attacks gain weight through timing, stance, body sequencing, displacement, and hitstop before gaining extra rotational amplitude.

The broad attacks remain intentionally larger:

- `Circular Cut` is a broad front-space attack rather than a full orbit;
- `Orbit Finisher` can sweep farther around Grace, but its authored cone and weapon rotation remain bounded below a full circle.

## Skeletal choreography

The active skeletal proxy now gives Sword its own pose layer instead of routing every weapon through the generic cut vocabulary.

The standard cut chain uses restrained:

```text
stance load
→ pelvis turn
→ spine / chest turn
→ shoulder drive
→ elbow extension
→ wrist / blade contact
→ controlled overshoot
→ braking recovery
```

The right weapon hand should not need to travel behind the plane of Grace's back for an ordinary Sword beat.

Sword-specific skeletal pose families now cover:

- normal cuts;
- broad cuts;
- thrusts;
- overhead Heavy;
- rising / launcher attacks;
- Dash Light;
- Dash Heavy;
- Aerial Light;
- Aerial Heavy.

Other weapon classes continue using the generic skeletal presentation until they receive their own authored class language.

## Context attack grammar

Context attacks are now explicit Light / Heavy pairs rather than one dash technique plus movement-dependent aerial categories.

### During an active dodge

```text
Light → Dash Light
Heavy → Dash Heavy
```

For Sword:

```text
Dash Light = Passing Cut
Dash Heavy = Rush Break
```

Dash Light is the faster passing slash. Dash Heavy is a more committed diagonal break with stronger stance, knockback, and hitstop.

Both reuse the existing dodge-cancel-to-technique path. They reset the ground combo chain and act as context openers rather than invisible combo-depth continuations.

### While airborne after jumping

```text
Light → Aerial Light
Heavy → Aerial Heavy
```

For Sword:

```text
Aerial Light = Comet Slash
Aerial Heavy = Falling Edge
```

Aerial Light preserves the jump arc and adds a modest target-following carry on contact.

Aerial Heavy commits Grace downward and arms the existing plunge-landing behavior. It remains a Heavy attack rather than being represented only as a generic `aerial_down` context.

Legacy `aerial_neutral`, `aerial_forward`, and `aerial_down` IDs remain supported for older prototype content, but the live player input path uses the explicit Light / Heavy contexts.

## All-class system contract

All 16 weapon classes now expose the same contextual input grammar when their rank-1 context techniques are unlocked:

```text
Dodge + Light → class Dash Light
Dodge + Heavy → class Dash Heavy
Jump / airborne + Light → class Aerial Light
Jump / airborne + Heavy → class Aerial Heavy
```

Sword is the first class with bespoke v0.3 skeletal choreography and named Heavy dash identity. Other classes inherit distinct generated Light / Heavy attacks using their existing class definitions until they receive authored animation passes.

## Manual test

Use Sword first.

### Ground chain

Try each string separately:

```text
L
L L
L L L
L L L L
L H
L L H
L L L H
L L L L H
H
```

Watch for:

- the blade spending most of its time in front / beside Grace;
- no ordinary backswing reaching far behind her;
- L1 and L2 feeling efficient and linked;
- L3 reading as a rising diagonal instead of an extreme uppercut;
- L4 reading broad without becoming a full spin;
- H1–H4 feeling progressively more committed without simply becoming larger arcs;
- thrusts looking level and directional.

### Dash pair

During a dodge:

```text
Dodge → Light
Dodge → Heavy
```

They should be visibly and mechanically different.

### Aerial pair

After jumping:

```text
Jump → Light
Jump → Heavy
```

Aerial Light should continue the airborne exchange. Aerial Heavy should commit downward toward a landing impact.

## Automated contracts

Existing registered weapon moveset regression:

```text
res://scenes/tests/weapon_moveset_smoke_test.tscn
```

now checks:

- the Sword Light-depth branch graph;
- Heavy branch at each Light depth;
- bounded ordinary Sword arc angles;
- bounded Circular Cut / Orbit Finisher coverage;
- level Driving Thrust geometry;
- distinct Sword Dash Light / Heavy definitions;
- distinct Sword Aerial Light / Heavy definitions.

Existing context-technique regression:

```text
res://scenes/tests/context_weapon_technique_smoke_test.tscn
```

checks that all 16 classes resolve explicit Dash Light, Dash Heavy, Aerial Light, and Aerial Heavy attacks while preserving the legacy aerial context IDs.

## Next use

Do not expand the Sword graph again until this vocabulary feels stable in play.

Once Sword is approved, use it as the quality reference for class-specific choreography passes. Heavy weapons should not simply copy Sword with slower timing, and flexible / ranged classes should preserve their own physical language.
