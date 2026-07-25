# Elemental Weapon Infusion v1

Weapon infusions are equipped from **Field Kit → Loadout → Weapon Infusion**. The row is controller navigable with the same D-pad/stick and confirm controls as the rest of the menu.

Selecting Fire, Ice, Lightning, or Poison equips that infusion. Selecting the active card again removes it. The equipped infusion is saved independently of weapon class and weapon mastery, so changing weapons preserves the chosen element.

## Combat contract

Every connected weapon strike retains its physical damage and mastery upgrades, then receives the equipped elemental payload:

- **Fire Edge** — fire element, Burning for 3 seconds, combustion and Fire reactions.
- **Frost Edge** — ice element, Chill for 2.6 seconds, thermal and Ice reactions.
- **Storm Edge** — lightning element, a brief 0.28 second Stun, electrical material and conductivity reactions.
- **Venom Edge** — poison element, Poisoned for 3.2 seconds.

Infusion does not add a combat input. It changes generated weapon payloads, so targets already using `PayloadReceiver`, `StatusReceiver`, thermal, combustion, electrical, and reaction components respond through their existing systems.

## Presentation

Procedural weapons blend toward the selected elemental color and gain emission. Ordinary slash trails blend strongly toward that color. Connected infused hits spawn an elemental impact burst. Runtime chain/whip rigs still receive the elemental payload and impact burst even when their custom geometry owns its own material.

## Test

Run:

```text
scenes/tests/weapon_infusion_smoke_test.tscn
```

Then play any combat scene:

1. Open the Field Kit and enter Loadout.
2. Move to Weapon Infusion using controller navigation.
3. Equip each element and confirm the weapon/trail color changes.
4. Strike a target with a StatusReceiver and confirm the matching status/reaction.
5. Select the active infusion again and confirm the weapon returns to physical-only behavior.
6. Save at a bed, reload, and confirm the chosen infusion persists.
