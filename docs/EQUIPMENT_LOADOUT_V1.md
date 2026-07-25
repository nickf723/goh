# Equipment and Loadouts v1

## Laboratory

Run:

```text
scenes/levels/prototypes/prototype_equipment_outfitter_lab_v1.tscn
```

The Adventurer's Outfitter connects unique gear ownership, persistent equipment slots, fixed stat modifiers, existing weapon movesets, treasure rewards, currency, buying, and selling.

## Equipment slots

- Weapon: changes the real WeaponController resource and moveset.
- Outfit: primarily changes an action-resource maximum.
- Charm: provides focused personal bonuses.
- Relic: provides utility and social bonuses.

## Available gear

### Weapons

- Practice Sword: balanced existing sword moveset.
- Training Hammer: existing hammer moveset and +1 Power.
- Training Spear: existing spear moveset and +1 Dexterity.

### Outfits

- Traveler's Coat: +2 maximum Stamina.
- Apprentice Robe: +2 maximum Mana.
- Ironweave Jacket: +2 maximum Stance.

### Charms

- Vital Knot: +2 maximum Health.
- Resonance Charm: +1 Focus.

### Relics

- Merchant's Token: +1 Charisma.
- Lucky Shard: +1 Luck.

## Rules

- Equipment is unique rather than stackable.
- Owned equipment and four equipped slot IDs participate in bed saves.
- Equipping removes the previous item's modifiers before applying the replacement.
- Resource-maximum modifiers preserve the same missing-resource amount when swapped.
- The Weapon slot loads the existing data-driven weapon and moveset into WeaponController.
- Equipped gear cannot be sold.
- Purchases and sales use the persistent Crown wallet.
- Buying, equipping, and selling require a second Confirm press.
- The comparison pane shows current and projected values before committing.

## Playtest route

1. Open the Resonance Charm chest on the left.
2. Enter the Outfitter with 180 starting crowns.
3. Compare the Shop entries and buy a weapon, outfit, and relic.
4. Move to Equip and equip each item.
5. Confirm the slot summary and projected stat values update.
6. Close the menu and use Light and Heavy attacks to verify the selected weapon moveset.
7. Reopen the Outfitter and attempt to sell equipped gear.
8. Equip a replacement, then sell the old piece.
9. Press F8 outside the menu to reset the laboratory.

## Smoke test

```text
scenes/tests/equipment_loadout_smoke_test.tscn
```

The smoke test verifies ownership, slot assignment, modifier replacement, equipped-sale protection, shop purchasing, selling, and restoration of the entry state.
