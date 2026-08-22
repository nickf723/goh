# Animal Behavior Lab Test Guide

Run:

`res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn`

The lab controls live in two on-screen panels. They are mouse-clickable and controller-focusable, so the test does not depend on raw letter or number shortcuts.

## Perception and relationship pass

1. Select Mallow with **Previous** or **Next** and approach her peacefully from the front.
2. Watch her stimulus change to **Sight** and her awareness rise.
3. Walk behind her or leave the pasture. Confirm Sight disappears while **Memory** remains briefly.
4. Return calmly and use **Feed**. Confirm one Field Treat is consumed and trust rises.
5. Use **Soothe** after raising fear with the debug button. Confirm fear and fear association decrease.
6. Use **Startle** on Mallow. Confirm her relationship becomes **Afraid**, fear spikes, and she flees from Grace's remembered position.
7. Move away and use **Make Noise**. Confirm nearby animals show **Hearing** or **Investigate** without requiring direct sight.
8. Select Ash or Cinder, switch Grace to **Threatening posture**, and approach one wolf from the front. Confirm the other wolf receives a **Social Alert** and gains territorial pressure even when it did not see Grace directly.
9. Return Grace to **Peaceful posture** and remain at a respectful distance. Confirm trust and familiarity rise slowly over time.

## Committed move lifecycle pass

1. Select Mallow, clear her drives, then raise Hunger until she chooses **Graze**.
2. Confirm Graze remains the active action through a visible preparation, feeding, and recovery beat instead of changing every decision tick.
3. Use **Startle** while she is grazing. Confirm the current action ends immediately and the next decision becomes a fear-driven retreat.
4. Threaten Ash or Cinder at close range. Confirm contact moves commit for their authored beat and do not flicker between Bite, Pounce, and Howl every brain interval.
5. Return to Peaceful posture and confirm the animal resumes ambient decisions only after the active action completes.

## Effect execution and vitals pass

1. Select Ash or Cinder, switch Grace to **Threatening posture**, and enter the wolf's authored attack reach.
2. Confirm the wolf commits one active move and Grace receives at most one consequence for that move; the active window must not repeat the hit every frame.
3. Step outside Bite reach. Confirm a committed contact effect does not damage Grace at a distance.
4. Confirm every animal now displays an **HP** percentage alongside its drives.
5. With both wolves present, confirm pack-support behavior remains focused on wolves rather than sheep or capybara.
6. Use **Reset Lab** and confirm the animals return to full HP without a stale move effect firing after reset.

The foundation smoke test owns the non-visual edge cases: species-scaled damage, health and stamina recovery, incapacitation and revival, duplicate request rejection, range filtering, authoritative empty target providers, area deduplication, and physical projectile spawning.

## Bonding and persistence pass

1. Select Mallow and stand near her in Peaceful posture.
2. Feed her three times. The bonding panel should show Trust above 58%, Familiarity above 45%, and **Eligible now: YES** once fear is calm.
3. Press **Bond Selected**. Mallow should become Bonded and enter Following mode.
4. Walk away through the lab. Confirm her action becomes **Follow Grace** and she closes the distance voluntarily.
5. Press **Follow / Stay**. Confirm she stops following but keeps the bond.
6. Press it again and confirm following resumes.
7. Press **Save Bonds**.
8. Use **Reset Lab**, then confirm the bond survives the position and drive reset.
9. Press **Reload Bonds** and confirm trust, familiarity, bond state, and Follow / Stay preference return from disk.
10. Press **Help / Heal** and confirm trust improves.
11. Press **Report Attack** and confirm trust falls, fear rises, and the harm-event count is saved.
12. Press **Clear This Bond** only when you want to remove that named animal's persistent record.

## Inventory

`Field Treat` is a real inventory item. Feed fails without one and consumes exactly one on success.

The lab starts with at least six treats. **Add 6 Treats** replenishes the testing stock without resetting relationships.

## Reset behavior

**Reset Lab** and the configured restart input reset positions, drives, vitals, effect-request memory, perception memory, selection, noise, and Grace's posture. Saved named-animal relationships remain intact.

Use **Clear This Bond** to reset one animal's relationship deliberately.

## Readouts

Each animal's overhead label shows:

- Relationship label
- Current stimulus
- Current intention
- Current action
- Trust
- Health
- Hunger
- Fear
- Social need

The left selected-animal panel additionally shows:

- Familiarity
- Awareness
- Remaining memory duration
- Fatigue
- Curiosity
- Territorial pressure

The right bonding panel additionally shows:

- Stable animal identity
- Field Treat count
- Bonded state
- Follow / Stay preference
- Current bond eligibility
- Bond thresholds and current values

## Relationship vocabulary

- **Hostile:** low trust combined with an aggressive disposition
- **Afraid:** strong current fear or learned fear association
- **Wary:** uncertain, uncomfortable, or mildly fearful
- **Neutral:** familiar enough to observe without a strong opinion
- **Curious:** positive trust or familiarity encourages voluntary approach
- **Trusting:** high persistent trust allows close contact and bonding
