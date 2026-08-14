# Weapon Moveset Completion Contract V1

An authored weapon class is not complete when its grounded Light/Heavy graph is complete. Each class pass must cover the entire combat input grammar and give every layer a mechanical reason to exist.

## Required authored layers

1. **Grounded combo graph**
   - Three or more Light beats.
   - Heavy entry plus Heavy branches from the grounded Light chain.
   - A clear class loop, payoff, and failure condition.

2. **Dash attacks**
   - Dash Light and Dash Heavy.
   - At least one must reinforce the class's positioning or engagement identity.

3. **Aerial attacks**
   - Aerial Light and Aerial Heavy.
   - Their movement, hit geometry, landing behavior, and follow-through must be authored, not only renamed generic attacks.

4. **Charge attacks**
   - Light Hold and Heavy Hold.
   - A charge may be a release attack, sustained technique, counter stance, traversal state, aiming mode, or another class-specific interaction.
   - Quick taps must preserve the ordinary Light/Heavy attack unless the class explicitly replaces them.

5. **Presentation**
   - Weapon trajectory and body pose must agree.
   - Cutting weapons must preserve edge alignment at contact.
   - Two-handed techniques must use the support-grip contract.
   - Movement and camera ownership must be explicit for every traversal or aiming technique.

6. **Validation**
   - The class smoke test must inspect grounded graph identity, both aerial attacks, both dash attacks, both charge attacks, live controller wiring, and the runtime/skeletal presentation scenes.

## Current authored class theses

- **Staff:** positioning, speed, technique.
- **Axe:** power, momentum, creating and exploiting openings.

Future class passes should begin by writing the thesis, then author all six layers around that thesis before the class is considered finished.
