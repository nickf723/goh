# Player Resource Loop v1 — Manual Test

## Goal

Confirm that Grace uses the same production resource behavior in every scene that instantiates the reusable Player scene.

## Primary route

Run:

`scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn`

1. Use LIGHT repeatedly. Every light attack should spend 1 stamina.
2. Continue until the next attack is refused for insufficient stamina.
3. Stop acting. Stamina should remain still for about 0.7 seconds, then refill from empty to full in roughly 2.4 seconds.
4. Attack as the bar begins recovering. The new expenditure should restart the recovery delay.
5. Use DODGE. It should spend 1 stamina and restart the same delay.
6. Start another attack or dodge while recovery is active. Stamina recovery should pause during the committed action and resume afterward.
7. Use a Heavy attack. Existing class-specific costs should remain distinct: Sword and Spear are generally cheaper; Hammer, Chain, and Whip heavies are more expensive.
8. Open FOCUS while stamina is recovering. Recovery should follow slowed world time and must not accelerate because of the menu.
9. Spend mana with a spell and take health damage. Neither resource should regenerate passively.
10. Reset or rest. Health, stamina, mana, and stance should return to their maximum values.

## Flexible-weapon regression

Run both:

- `scenes/levels/prototypes/prototype_chain_weapon_lab_v1.tscn`
- `scenes/levels/prototypes/prototype_whip_weapon_lab_v1.tscn`

Confirm that stamina recovers at the same rate as the Weapon Combat Arena. There should be no lab-specific double regeneration.

## Expected resource policy

| Resource | Passive behavior |
|---|---|
| Health | No passive regeneration in v1 |
| Stamina | 0.7-second delay, then full recovery in about 2.4 seconds |
| Mana | No passive regeneration in v1 |
| Stance | 2-second delay, then full recovery in about 4 seconds |

The HUD should continue to display the live `GameState` values throughout.
