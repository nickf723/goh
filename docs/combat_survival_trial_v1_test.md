# Combat Survival Trial v1 — Manual Test

## Scene

`res://scenes/levels/prototypes/prototype_combat_survival_trial_v1.tscn`

## Purpose

Verify the first complete survival-and-supplies exchange: world pickup collection, saved inventory counts, paused Field Kit assignment, four direct quick-item slots, committed Healing Flask use, thrown Oil and Noise Maker delivery, readable enemy attacks, directional Guard, Dodge, stamina and stance recovery, stance break, critical punishment, and defeat/reset flow.

## Controls

| Action | Keyboard / Mouse | Controller |
|---|---|---|
| Move | WASD | Left stick |
| Camera | Mouse | Right stick |
| Interact / collect | E | Face B |
| Full Field Kit | Tab / M | Menu / Start |
| Menu navigate | WASD / arrows | D-pad |
| Menu choose / back | Enter / Esc | Confirm / Cancel |
| Light attack | Left mouse / J | Left shoulder |
| Heavy attack | Mouse 4 / K | Right shoulder |
| Guard | F / Mouse 5 | Left face (Switch Y / Xbox X) |
| Dodge | C | Face A |
| Quick Item Up | H / Up arrow | D-pad Up |
| Other quick slots | Arrow directions | D-pad directions |
| Lock-on | T | Right-stick click |
| Reset trial | F8 in editor | — |

Outside the Field Kit and Focus, the D-pad uses items directly. While Focus is open it navigates spells; while the paused Field Kit is open it navigates menu rows and tabs.

## Inventory and assignment route

1. Launch the scene. Confirm the compact belt shows `Flask ×3` in Up and empty Left, Right, and Down slots.
2. Collect the dark Oil Flask cache on Grace's left and the orange Noise Maker cache on her right. Confirm each pickup disappears and the trial HUD reports `OIL ×2` and `NOISE ×2`.
3. Open the Field Kit with Tab, M, or the controller Menu button.
4. On Loadout, select the D-pad Left item slot. The menu moves to Items in assignment mode.
5. Assign Oil Flask. Return to Loadout and assign Noise Maker to D-pad Right.
6. Close the menu. Confirm the compact belt now shows Flask Up, Oil Left, Noise Right, and the correct shared counts.
7. Throw Oil with D-pad Left. Confirm Grace performs the short committed use, a dark flask follows the current aim, an oil patch appears where it lands, and Oil decreases to one.
8. Move an enemy through the Oil and hit the patch or oily enemy with Fire. Confirm the existing oily + fire reaction can ignite it.
9. Throw the Noise Maker with D-pad Right. Confirm an orange projectile lands, expands a visible sound pulse, emits shared distraction evidence, and Noise decreases to one.
10. For the complete investigation response, carry a Noise Maker into the Perception and Investigation Laboratory and throw it out of sight of an observer. The observer should hear the shared stimulus at the landing point rather than at Grace's position.
11. Reopen the Field Kit and reassign either item to Down. Confirm the belt changes immediately without changing inventory counts.
12. Clear a quick slot from assignment mode. Confirm the slot becomes empty and no item is lost.

## Survival route

1. Let the Round 1 Goblin hit Grace. Confirm Health and Stance fall and any active item use is interrupted without consuming stock.
2. Create space and use the Healing Flask. Confirm Grace slows, the bottle moves toward her face, two Health restore only after about 0.9 seconds, and Flask stock falls by one.
3. Guard normally, Perfect Guard late in the red windup, Dodge through an impact, and break enemy Stance.
4. Defeat Round 1. Confirm Round 2 spawns two enemies without restoring Health or consumable stock.
5. Defeat both enemies and confirm the objective reports completion.
6. Press F8. Confirm Health, Mana, Stamina, Stance, and Flask refill; Oil and Noise return to zero; both supply pickups reappear; and Round 1 restarts.

## Persistence contract

- Inventory counts and four assigned item IDs live in `GameState`, not individual belt slots.
- A successful use consumes shared stock only after its committed effect or delivery succeeds.
- Rest refills definitions marked refillable, currently Healing Flask, without manufacturing Oil or Noise Makers.
- Saved games include inventory, belt assignments, and unique collected-pickup IDs.
- Two slots assigned to the same ordinary item share one count.

## Expected presentation

- Pickups rotate and hover with a colored item label.
- The bottom-right quick belt remains compact and updates immediately after collection, use, or assignment.
- The Field Kit Items tab shows item descriptions, quantities, refill rules, and an explicit Clear Slot choice.
- Thrown items follow the camera or lock-on aim.
- Oil reuses the existing reactive Status Surface rather than creating a second elemental reaction path.
- Noise Maker reuses the shared perception stimulus manager and shows a brief expanding sound ring.
- Enemy red/gold telegraphs remain the primary defense timing language.

## Known v1 limits

- Healing Flask, Oil Flask, and Noise Maker are the first three authored quick items.
- The survival-trial combat brains do not investigate perception stimuli; use the Perception Laboratory for the full Noise Maker AI response.
- Enemy drop tables, treasure-container opening, crafting, shops, item sorting, and pickup animation are deferred.
- Production levels must give unique persistent pickups a stable `pickup_id`; the trial caches are deliberately resettable.
- Oil uses a temporary scaled instance of the existing prototype oil patch.
- Controller rumble, final animation, audio, icons, and item-belt accessibility options are deferred.
