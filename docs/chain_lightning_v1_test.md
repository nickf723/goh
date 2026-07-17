# Chain Lightning v1 Test

## Goal

Use the new spell modifier framework to add the first on-hit spell upgrade.

```text
unlock Chain Lightning -> equip Lightning Spark -> hit one target -> arc jumps to nearby targets
```

## What changed

- Adds `chain_lightning` to the unlock catalog.
- Adds a `Chain Lightning` entry to `SpellModifierRegistry`.
- Uses the existing payload modifier path to turn `Lightning Spark` into `Chain Lightning` after unlock.
- Adds the first registry-driven `on_hit` behavior.
- Generic projectiles now ask `SpellModifierRegistry.apply_on_hit_effects(...)` after a payload lands.
- Chain Lightning can jump to nearby enemies without repeating targets already touched by the projectile or chain.
- The upgrade lab adds a Chain Lightning pedestal and includes it in F6 shortcut unlocks.

## Test scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

## Test flow

1. Run Current Scene.
2. Press F8 to clear lab progress if needed.
3. Equip `Lightning Spark` from the spell focus menu.
4. Cast at the center targets before unlocking.
5. Confirm it behaves like normal Lightning Spark and only hits the first target.
6. Use the `Chain Lightning` pedestal, or press F6.
7. Open Relics and confirm `Chain Lightning` appears under Spell Upgrades.
8. Equip `Lightning Spark` again if needed.
9. Aim at one of the center targets near the target cluster.
10. Cast Lightning Spark.
11. Confirm the first hit message says `Chain Lightning`.
12. Confirm one or two nearby targets also react with `Chain Lightning Arc` messages.
13. Confirm a brief lightning arc appears between targets.
14. Use Target Reset and repeat from a different target.
15. Press F8 and confirm Lightning Spark returns to normal non-chain behavior.

## Regression checks

- Firebolt still casts normally.
- Charged Firebolt still charges, rumbles, and uses the charged impact polish.
- Ice Lance still casts normally before unlocking Piercing Ice Lance.
- Piercing Ice Lance still pierces after unlock.
- Spell menu still equips without firing.

## Known limitations

- Chain arcs use prototype box-mesh lightning beams, not final VFX.
- Chain target selection uses nearest eligible enemy in range.
- There is no wet/conductive priority yet.
- Chain jumps do not recursively trigger new chain behaviors, by design for v1.
- The lab target spacing affects how obvious the jumps are.
