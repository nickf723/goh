# Hit Reactions and Anti-Stunlock v1

Run:

```text
scenes/levels/prototypes/prototype_hit_reaction_lab_v1.tscn
```

## Shared reaction contract

`HitReactionController` combines damage, stance damage, knockback, attack tags, mass, armor, current poise, and temporary reaction resistance. It resolves an impact into:

- Resist
- Flinch
- Stagger
- Launch
- Guard Break
- Super Armor
- Adapted

Every interrupt builds temporary reaction resistance. Fast repeated hits therefore become less disruptive until the attacker pauses long enough for resistance to decay. Poise also regenerates independently.

## Lab profiles

- **Light Gremlin:** light hits flinch, repeated hits stagger, launcher attacks lift it, and rapid pressure eventually triggers Adapted.
- **Armored Goblin:** ordinary light attacks are resisted; heavy guard-break attacks interrupt it.
- **Unstoppable Brute:** permanent super armor demonstrates committed actions that receive damage and feedback without displacement.

## Controls

- Light attack: J / left mouse / controller left face
- Heavy attack: K / mouse 4 / controller right face
- Reset: F8

The compact panel reports each target's current reaction, poise, adaptation, and armor state.

## Automated contract scene

```text
scenes/tests/hit_reaction_smoke_test.tscn
```

The test covers light flinch, armored resistance, guard break, launch motion, super armor, and repeated-hit adaptation.
