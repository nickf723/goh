# Grace of Humanity — Weapon Combat Identity v0.2

## Goal

The first Arsenal Dojo pass proved that all sixteen weapon classes can coexist in one comparison space, but most unfinished classes still reduced to the same abstract interaction:

```text
Light bonk
Heavy bonk
```

v0.2 changes the combat contract so classes differ by **how they occupy space and what contact means**, not only by damage, speed, and reach numbers.

## Range bug fixed

The shared melee query previously used a sphere centered in front of Grace with the entire authored attack range as its radius. The final cone test checked direction but did not re-check true planar distance from Grace.

That silently inflated reach. Large proxy ranges made the issue extreme enough that a target could be damaged from across the dojo.

`SafeWeaponController` now treats authored range as a hard planar contract. Candidate contacts beyond that range plus a small target-body allowance are rejected.

Ranged proxy classes no longer use the melee sphere at all.

## Geometry vocabulary

The combat identity layer currently exposes:

```text
arc
line
radial
precision ray
fan rays
returning ray
```

These are gameplay-query identities, not final animation or VFX assets.

### Arc

Default melee language for Sword, Axe, Mace, Daggers, Gauntlets, Halberd sweeps, and similar attacks.

The existing cone still matters, but true range is now enforced from Grace.

### Line

Used by narrow Lance thrusts and Staff thrusts.

Targets must lie inside a narrow forward corridor, allowing a long weapon to feel precise rather than like a large cone.

### Radial

Used by authored ground slams and selected wide heavy Flail/Scythe attacks.

The query centers on Grace rather than pretending a circular impact is a forward cone.

### Precision ray

Bow proxy attacks resolve the first physical contact along the shot line. Walls and nearer targets block farther targets.

### Fan rays

Shuriken throws use three rays on Light and five on Heavy. A volley therefore occupies a fan rather than a giant ranged sphere.

### Returning ray

Boomerang uses a forward ranged pass and schedules a reduced return strike on an outbound target after a short delay.

The current streak visualization is a prototype readability effect. Final boomerang travel should eventually use a proper moving weapon asset.

## Contact identity

`WeaponClassCombatIdentity` enriches the payload after normal moveset/mastery processing and before the target receives it.

Current class intentions:

| Class | v0.2 contact identity |
| --- | --- |
| Sword | balanced push and baseline flow |
| Lance | narrow line pressure and thrust precision |
| Axe | heavy knockback, stance pressure, sunder tag |
| Bow | first-contact ray, precision-heavy critical pressure |
| Hammer | planted force, very high heavy knockback, heavy-impact tag |
| Mace | heavy stagger / daze |
| Daggers | low displacement, later-Light flurry damage/critical pressure |
| Whip | restrained force; physical whip rig remains targeting authority |
| Chains | strong force; mastery pull tags reverse force toward Grace |
| Gauntlets | close pressure, later-combo stance pressure, Heavy launcher behavior |
| Flail | broad momentum and strong Heavy displacement |
| Halberd | Heavy hooks pull targets toward Grace instead of pushing them away |
| Boomerang | outbound hit plus reduced delayed return hit |
| Scythe | Heavy attacks gain an execution bonus against targets at 35% health or lower |
| Staff | low-force spellweave identity; fuller spell-cancel integration remains a later authoring pass |
| Shuriken | Light applies `marked`; Heavy consumes `marked` for bonus damage/critical force |

## Authored systems still win

Whip and Chains already have runtime physical rigs with custom target-finding behavior. Those rigs remain authoritative. v0.2 only applies the universal true-range safety filter and contact identity around them.

Likewise, existing authored movesets, animation poses, footwork, mastery upgrades, aerial techniques, dash techniques, and hit-stop values remain in place.

## Prototype ranged caveat

Bow, Shuriken, and Boomerang now use obstacle-respecting ray geometry and visible transient streaks, but these are **not final projectile implementations**.

The final weapon pipeline should eventually supply:

```text
Bow      → actual arrow projectile / draw-release animation
Shuriken → actual thrown star objects / volley trajectories
Boomerang→ actual outbound and returning moving weapon
```

The present ray layer exists to test spacing, occlusion, hit priority, attack timing, and class identity before asset production.

## Playtest questions

Use:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

Focus on contrasts rather than balance numbers:

- Does Lance feel like a line rather than a narrow Sword?
- Does Hammer move targets enough to communicate its weight without becoming slapstick?
- Does Mace's stagger make Heavy contact meaningfully different from Axe?
- Do Daggers/Gauntlets reward staying close and continuing pressure?
- Does Halberd pulling a target inward create useful follow-ups?
- Does Scythe's low-health execution window create a recognizable finishing role?
- Does Shuriken Light → Heavy create a readable mark/cash-out rhythm?
- Does Bow stop cleanly on the first target or wall?
- Does Boomerang's return beat feel promising enough to justify a real projectile later?

## Next round

After geometry/contact identity survives playtesting, the next high-value combat pass is defender presentation:

```text
impact anticipation
→ local flinch
→ stagger / launch pose
→ controlled displacement
→ damping
→ authored recovery
```

That pass should reduce the remaining stiff / ragdoll-like feel without weakening the systemic force model.