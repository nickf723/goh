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
| Move menu cursor | WASD or arrows | D-pad or left stick |
| Menu tabs | Q / E | Left / Right shoulder |
| Menu choose / back | Enter / Esc | Confirm / Cancel |
| Light attack | Left mouse / J | Left shoulder |
| Heavy attack | Mouse 4 / K | Right shoulder |
| Guard | F / Mouse 5 | Left face (Switch Y / Xbox X) |
| Dodge | C | Face A |
| Quick Item Up | H / Up arrow | D-pad Up |
| Other quick slots | Arrow directions | D-pad directions |
| Lock-on | T | Right-stick click |
| Reset trial | F8 in editor | — |

Outside the Field Kit and Focus, the D-pad uses items directly. While Focus is open it navigates spells. The paused Field Kit uses a spatial tile cursor: D-pad, stick, WASD, or arrows move across the grid, while shoulder buttons or Q/E change the horizontal icon tabs.

## Inventory and assignment route

1. Launch the scene. Confirm the compact belt shows `Flask ×3` in Up and empty Left, Right, and Down slots.
2. Collect the dark Oil Flask cache on Grace's left and the orange Noise Maker cache on her right.
3. Open the Field Kit. Confirm the old left sidebar is gone: large icon tabs run across the top and the main canvas uses equipment tiles rather than text rows.
4. On Loadout, confirm the weapon has a visual summary card, the four Spell Ring slots form a tile row, and the four directional Quick Belt slots form a second tile row.
5. Select the D-pad Left belt tile. Confirm Items opens with three large item tiles, a highlighted selection, and a dedicated detail panel containing count, description, refill rule, and existing assignments.
6. Assign Oil Flask. Confirm the menu returns to the exact Left belt tile.
7. Change to Items with the shoulder buttons or Q/E. Select Noise Maker and confirm. The menu should transform into a spatial D-pad cross showing Up, Left, Right, Down and each slot's current item.
8. Choose Right. Confirm the inventory grid returns with Noise Maker still selected and its tile/detail panel now reports the Right assignment.
9. Reopen Noise Maker's direction picker, press Cancel, and confirm it returns to the same inventory tile without changing the belt.
10. Move around the item grid with all four directions. Confirm focus follows the spatial arrangement and remains visible.
11. Close the menu. Confirm the compact belt now shows Flask Up, Oil Left, Noise Right, and the correct shared counts.
12. Throw Oil with D-pad Left. Confirm Grace performs the short committed use, a dark flask follows the current aim, an oil patch appears where it lands, and Oil decreases to one.
13. Move an enemy through the Oil and hit the patch or oily enemy with Fire. Confirm the existing oily + fire reaction can ignite it.
14. Throw the Noise Maker with D-pad Right. Confirm an orange projectile lands, expands a visible sound pulse, emits shared distraction evidence, and Noise decreases to one.
15. For the complete investigation response, carry a Noise Maker into the Perception and Investigation Laboratory and throw it out of sight of an observer.
16. Verify the alternate slot-first flow still works: Loadout belt tile → item grid → assignment. Use the final Clear Slot tile to empty a direction without losing stock.

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
- The Field Kit uses horizontal icon tabs, spacious visual tiles, a high-contrast gold cursor, and remembered positions instead of a sidebar of text rows.
- Loadout presents the weapon, Spell Ring, and Quick Belt as distinct visual bays.
- Items presents a three-column icon grid, a dedicated detail panel, and a spatial D-pad assignment cross.
- Both item-first and belt-slot-first assignment routes return to the originating tile. The slot-first route retains an explicit Clear Slot tile.
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
