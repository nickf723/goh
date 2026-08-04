# Animal Behavior Lab Test Guide

Run:

`res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn`

The lab controls now live in the on-screen panel. They are mouse-clickable and controller-focusable, so the test does not depend on raw letter or number shortcuts.

## Suggested test pass

1. Select Mallow with **Previous** or **Next** and approach her peacefully from the front.
2. Watch her stimulus change to **Sight** and her awareness rise.
3. Walk behind her or leave the pasture. Confirm Sight disappears while **Memory** remains briefly.
4. Return calmly, move close enough to interact, and use **Feed** twice. Confirm trust rises and the relationship changes toward **Curious**.
5. Use **Soothe** after raising fear with the debug button. Confirm fear and fear association decrease.
6. Use **Startle** on Mallow. Confirm her relationship becomes **Afraid**, fear spikes, and she flees from Grace's remembered position.
7. Move away and use **Make Noise**. Confirm nearby animals show **Hearing** or **Investigate** without requiring direct sight.
8. Select Ash or Cinder, switch Grace to **Threatening posture**, and approach one wolf from the front. Confirm the other wolf receives a **Social Alert** and gains territorial pressure even when it did not see Grace directly.
9. Return Grace to **Peaceful posture** and remain at a respectful distance. Confirm trust and familiarity rise slowly over time.
10. Use **Hungry**, **Afraid**, **Lonely**, **Curious**, and **Territorial** to compare persistent drives with perception and relationship state.
11. Use **Reset Lab** or the configured restart input. Confirm positions, drives, perception memory, relationships, selection, noise, and posture reset.

## Readouts

Each animal's overhead label shows:

- Relationship label
- Current stimulus
- Current intention
- Current action
- Trust
- Hunger
- Fear
- Social need

The selected-animal panel additionally shows:

- Familiarity
- Awareness
- Remaining memory duration
- Fatigue
- Curiosity
- Territorial pressure

## Relationship vocabulary

- **Hostile:** low trust combined with an aggressive disposition
- **Afraid:** strong current fear or learned fear association
- **Wary:** uncertain, uncomfortable, or mildly fearful
- **Neutral:** familiar enough to observe without a strong opinion
- **Curious:** positive trust or familiarity encourages investigation
- **Trusting:** high persistent trust allows much closer peaceful contact
