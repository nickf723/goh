# Combat Survival Trial v1 — Manual Test

## Scene

`res://scenes/levels/prototypes/prototype_combat_survival_trial_v1.tscn`

## Purpose

Verify the first complete player survival exchange: readable enemy windups, directional Guard, Perfect Guard timing, stamina and stance pressure, guard break, Dodge invulnerability, hit reactions, player defeat, enemy stance break, critical punishment, and resource recovery.

## Controls

| Action | Keyboard / Mouse | Controller |
|---|---|---|
| Move | WASD | Left stick |
| Camera | Mouse | Right stick |
| Light attack | Left mouse / J | Left shoulder |
| Heavy attack | Mouse 4 / K | Right shoulder |
| Guard | F / Mouse 5 | Face X |
| Dodge | C | Face A |
| Lock-on | T | Right-stick click |
| Reset trial | F8 in editor | — |

Focus and Cast keep their established trigger bindings. Guard deliberately uses the free controller face X slot so Light and Heavy remain a consistent shoulder pair.

## Test route

1. Launch the scene and confirm the compact HUD reports Round 1, one enemy, Health, Stamina, Stance, and `DEFENSE READY`.
2. Let the Goblin approach without defending. Confirm the red windup becomes a gold impact, Grace loses Health and Stance, her current action is interrupted, and she recoils briefly.
3. Reset with F8. Hold Guard well before the windup. Confirm the blue guard surface appears, the hit removes Stamina and Stance but no Health, and both resources stop regenerating until Guard is released.
4. Release Guard. Confirm Stamina waits for its short delay and Stance waits for its longer delay before both recover to their maximums.
5. Tap Guard during the final red windup. Confirm the shield flashes gold, the HUD reports `Perfect Guard`, Grace spends no Health, Stamina, or Stance, and the enemy is staggered and loses Stance.
6. Break the enemy's Stance with attacks or Perfect Guards. Confirm its critical window opens and a melee weapon hit converts that opening into Health damage.
7. Hold Guard through repeated attacks until Stamina or Stance reaches zero. Confirm the shield flashes red, Guard ends, Grace is pushed back and staggered, and she cannot attack, cast, dodge, or guard during the break.
8. Face away from the enemy while guarding. Confirm a rear hit bypasses Guard and damages Grace.
9. Dodge through an impact. Confirm no Health or Stance is lost during the invulnerability window.
10. Defeat the Round 1 Goblin. Confirm Round 2 spawns a Goblin and Gremlin without healing Grace.
11. Use Lock-on, Dodge, Guard, and attacks to manage both directions. Confirm directional Guard does not protect Grace from an attacker behind her.
12. Defeat both enemies. Confirm the objective changes to trial complete and no further wave spawns.
13. Allow Grace's Health to reach zero in a fresh run. Confirm defeat locks actions and F8 restores the Player transform, all rest resources, defense state, recovery timers, and Round 1.

## Expected presentation

- Guard is a translucent blue surface directly in front of Grace.
- The Perfect Guard window briefly enlarges the surface and a successful deflection flashes gold.
- A normal blocked hit flashes blue and produces a short recoil.
- Guard break and direct damage flash red.
- Enemy red/gold telegraphs remain the primary timing language.
- The trial HUD remains confined to a compact panel and does not cover the center of the arena.

## Known v1 limits

- Guard uses a universal magical-metal surface rather than weapon-specific block animations.
- Guarding is directional but does not yet rotate Grace toward nearby attackers automatically.
- Perfect Guard timing and stamina/stance costs are first-pass tuning values.
- Bespoke hazards and bosses that call `GameState.take_damage()` directly still need to opt into the common defense resolver.
- Controller rumble, hit stop, production animation, audio, and accessibility timing assists are deferred.
