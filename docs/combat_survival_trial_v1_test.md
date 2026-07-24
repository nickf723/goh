# Combat Survival Trial v1 — Manual Test

## Scene

`res://scenes/levels/prototypes/prototype_combat_survival_trial_v1.tscn`

## Purpose

Verify the first complete player survival exchange: readable enemy windups, directional Guard, Perfect Guard timing, stamina and stance pressure, guard break, Dodge invulnerability, hit reactions, player defeat, enemy stance break, critical punishment, resource recovery, and the four-slot quick-item belt's committed Healing Flask use.

## Controls

| Action | Keyboard / Mouse | Controller |
|---|---|---|
| Move | WASD | Left stick |
| Camera | Mouse | Right stick |
| Light attack | Left mouse / J | Left shoulder |
| Heavy attack | Mouse 4 / K | Right shoulder |
| Guard | F / Mouse 5 | Left face (Switch Y / Xbox X) |
| Dodge | C | Face A |
| Quick Item Up | H / Up arrow | D-pad Up |
| Lock-on | T | Right-stick click |
| Reset trial | F8 in editor | — |

The four quick-item slots use D-pad Up, Left, Right, and Down, with the arrow keys as keyboard mirrors. Only Up is equipped in this slice. While Focus is open, those same directions navigate the spell menu instead of using items. Focus and Cast keep their established trigger bindings. Guard deliberately uses the free physical left-face slot (Switch Y / Xbox X) so Jump remains on the top face button and Light and Heavy remain a consistent shoulder pair.

## Test route

1. Launch the scene and confirm the compact HUD reports Round 1, one enemy, Health, Stamina, Stance, and `DEFENSE READY`.
2. Confirm the compact bottom-right belt shows `Flask ×3` in Up and `Empty` in the other three slots.
3. Let the Goblin approach without defending. Confirm the red windup becomes a gold impact, Grace loses Health and Stance, her current action is interrupted, and she recoils briefly.
4. Create space and press D-pad Up or H. Confirm Grace slows, a small flask moves from her hand toward her face, the use meter fills for about 0.9 seconds, two Health are restored only at completion, and the charge count falls to two.
5. Begin another Flask use and let the Goblin hit Grace before it completes. Confirm the use is cancelled, no Health is restored, and no charge is consumed.
6. Restore full Health and attempt another Flask. Confirm it does not begin and no charge is wasted.
7. Reset with F8. Confirm the Flask refills to three charges together with Health, Mana, Stamina, and Stance.
8. Hold Guard well before the windup. Confirm the blue guard surface appears, the hit removes Stamina and Stance but no Health, and both resources stop regenerating until Guard is released.
9. Release Guard. Confirm Stamina waits for its short delay and Stance waits for its longer delay before both recover to their maximums.
10. Tap Guard during the final red windup. Confirm the shield flashes gold, the HUD reports `Perfect Guard`, Grace spends no Health, Stamina, or Stance, and the enemy is staggered and loses Stance.
11. Break the enemy's Stance with attacks or Perfect Guards. Confirm its critical window opens and a melee weapon hit converts that opening into Health damage.
12. Hold Guard through repeated attacks until Stamina or Stance reaches zero. Confirm the shield flashes red, Guard ends, Grace is pushed back and staggered, and she cannot attack, cast, dodge, guard, or use an item during the break.
13. Face away from the enemy while guarding. Confirm a rear hit bypasses Guard and damages Grace.
14. Dodge through an impact. Confirm no Health or Stance is lost during the invulnerability window.
15. Defeat the Round 1 Goblin. Confirm Round 2 spawns a Goblin and Gremlin without healing Grace or refilling Flask charges.
16. Use Lock-on, Dodge, Guard, attacks, and Flask timing to manage both directions. Confirm directional Guard does not protect Grace from an attacker behind her.
17. Defeat both enemies. Confirm the objective changes to trial complete and no further wave spawns.
18. Allow Grace's Health to reach zero in a fresh run. Confirm defeat locks actions and F8 restores the Player transform, all rest resources, defense state, item state and charges, recovery timers, and Round 1.

## Expected presentation

- Guard is a translucent blue surface directly in front of Grace.
- The Perfect Guard window briefly enlarges the surface and a successful deflection flashes gold.
- A normal blocked hit flashes blue and produces a short recoil.
- Guard break and direct damage flash red.
- Enemy red/gold telegraphs remain the primary timing language.
- The four-slot item belt stays compact in the bottom-right corner and shows the active use progress without covering play.
- The Healing Flask is represented by a small procedural bottle in Grace's hand during the committed use.
- The trial HUD remains confined to a compact panel and does not cover the center of the arena.

## Known v1 limits

- Guard uses a universal magical-metal surface rather than weapon-specific block animations.
- Guarding is directional but does not yet rotate Grace toward nearby attackers automatically.
- Perfect Guard timing and stamina/stance costs are first-pass tuning values.
- Healing Flask is the only authored consumable; inventory assignment, pickups, persistent quantities, and production animations are deferred.
- Quick-item effects currently restore one runtime resource; broader item behaviors will extend the shared definition/controller contract.
- Bespoke hazards and bosses that call `GameState.take_damage()` directly still need to opt into the common defense resolver.
- Controller rumble, hit stop, production animation, audio, and accessibility timing assists are deferred.
