# Lock-On and Combat Targeting v1

## Controls

- Controller: click the right stick to lock or release.
- Keyboard: press `T` to lock or release.
- While locked, flick the right stick left or right to switch targets.
- Keyboard target switching remains `,` and `.`.

## What changed

- Hard-lock acquisition now scores screen-center proximity, world distance, visibility, and threat class.
- Targets behind Grace or behind an obstruction are rejected during acquisition.
- A locked target may briefly pass behind cover without immediately breaking lock.
- Sustained obstruction, leaving the expanded range, defeat, or invalidation releases the lock.
- Directional switching uses the targets' actual screen positions.
- The camera smoothly shifts to an over-the-shoulder composition and dynamically pitches to keep differently sized targets visible.
- A subtle blue marker identifies the current soft-aim candidate.
- Unlocked spells and melee attacks receive narrow soft aim when a valid visible target is close to the center of the screen.
- Hard-lock marker color distinguishes normal enemies, bosses, Metal Tether anchors, and Soul Grip targets.
- Spells and weapons continue to consume the same player targeting API.

## Playtest

Run either:

- `scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn`
- `scenes/levels/prototypes/church_trial_room_v1.tscn`

Test the following:

1. Approach multiple enemies without locking. The small blue marker should favor the enemy nearest the center of the screen.
2. Cast a projectile just beside that enemy. Soft aim should correct toward its center mass.
3. Press R3 or `T`. The gold marker should replace the soft marker.
4. Move around the target and verify Grace faces it while the camera keeps both characters readable.
5. Flick the right stick left and right to switch by screen direction.
6. Put a thin obstacle between Grace and the target briefly; lock should survive.
7. Remain behind solid cover; lock should release after the visibility grace period.
8. Defeat the target; lock should release cleanly.
9. Lock the animated armor boss; its marker should use the boss color.
10. Try an unlocked melee attack with an enemy near screen center; the attack direction should receive the same restrained soft correction.

## Smoke test

Run:

`scenes/tests/combat_targeting_smoke_test.tscn`

The test verifies center-screen acquisition, rightward target switching, soft-target selection, and soft-aim direction.
