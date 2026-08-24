# Mob Engine Foundation v1

## Purpose

The Mob Engine provides one reusable behavioral grammar for animals, monsters, enemies, ambient wildlife, summons, and trainable familiars.

It separates five concepts that were previously easy to entangle:

1. **Move**: what an action physically does.
2. **Move Policy**: when a creature is willing to consider that action.
3. **Species**: body plan, ecology, default temperament, and normal movepool.
4. **Individual**: personality overrides, condition, age, mutation, training, and temporary context.
5. **Familiar Build**: level, experience, learned moves, equipped movepool, move ranks, and augments.

This allows one shared `Bite` definition to serve wolves, sheep, capybaras, gorgons, and gremlins without copying its damage and targeting data into five species scripts.

## Move definitions

A `MobMoveDefinition` describes reusable action identity and mechanics:

- Move ID and display name
- Action kind and target mode
- Semantic tags
- Required body tags
- Required locomotion capabilities
- Minimum and maximum range
- Cooldown
- Base utility
- Startup, active, and recovery timing
- Phase-specific interruption policy
- Generic effect data
- Rank-scaling properties
- Available augment slots

The first shared move library contains:

- Idle
- Graze
- Flee
- Bite
- Headbutt
- Pounce
- Backstep
- Pack Howl
- Mire Spit
- Wade
- Stone Gaze
- Tail Sweep

A move is not tied to one species, actor scene, animation, or AI script.

## Body-plan constraints

Moves can require anatomical capabilities.

Examples:

- Bite requires `jaw`.
- Graze requires `mouth`.
- Pounce requires `legs`.
- Pack Howl requires `voice`.
- Wade requires `swimmer`.
- Stone Gaze requires `gaze`.
- Tail Sweep requires `tail`.

The evaluator rejects a move when the species body plan lacks its required tags. Future body plans can include wings, hands, horns, shells, tentacles, burrowing limbs, multiple heads, incorporeal bodies, or machine components without changing the evaluator.

`MobBodyPlanCatalog` now supplies canonical quadruped, avian, fish, serpentine, amphibian, insectoid, arachnid, crustacean, cephalopod, humanoid, amorphous, sessile, and mythic-composite structures. A body plan contributes core anatomy, part counts, a mobility kind, and default locomotion. Species add their distinctive organs and can override counts, so an Octopus inherits eight tentacles while a future Squid can override the same plan without a parallel actor class. Sessile creatures intentionally validate without fake walking data.

Species inheritance is separate from body-plan reuse. A child species inherits its parent's statistics, personality, anatomy, tags, moveset policies, and familiar profile; nested dictionaries merge, tag collections can add or remove entries, and explicit child values remain authoritative. This supports lightweight regional variants without copy-pasting an entire creature.

Locomotion is resolved as a second capability layer. Ground, swimming, flight, climbing, and burrowing are movement modes; runner, serpentine, hover, and jumper are modifiers or transitions. The shared catalog validates anatomy and dependencies, so species can combine modes without introducing species-specific brain code. `MobLocomotionExecutor` consumes that profile at runtime for legal transitions, medium validation, planar/surface/volumetric steering, water currents, surface buoyancy, gravity policy, and explicitly activated modifiers. See [`ANIMAL_BODY_LOCOMOTION_AND_EFFECTS_V1.md`](ANIMAL_BODY_LOCOMOTION_AND_EFFECTS_V1.md).

## Active-phase effects

A committed execution claims one normalized effect request when it first crosses into the active phase. The request preserves targeting, range, radius, effect data, source lineage, and delivery class. `MobMoveEffectExecutor` remembers request identities, asks an authoritative actor provider for targets, filters range and duplicates, resolves contact and area payloads, spawns physical projectiles, routes recovery, and exposes movement or custom effects to specialized executors.

Confirmed contact, area, projectile, status, and buff effects convert into the existing `DamagePayload` contract. `MobVitalsComponent` supplies the corresponding species-derived health, stamina, recovery, and incapacitation receiver for reusable animal actors. The canonical combat `StatusReceiver` retains timed primary statuses and augment riders and exposes them as self tags for later policy decisions.

This keeps move choice, animation timing, target confirmation, and world consequence separate while preserving the project's Actor → Action → Payload → Target → Receiver → Reaction → Consequence grammar.

## Move policies

A `MobMovePolicy` attaches a shared move to one species or individual with contextual rules.

Policies can constrain:

- Health range
- Target distance
- Ally and enemy counts
- Minimum level
- Required context tags
- Any-of context tags
- Forbidden context tags
- Self-state tags
- Target-state tags
- Personality score weights
- Contextual score modifiers
- Policy-role tags

### Shared Bite example

The physical Bite move remains the same.

A wolf policy treats Bite as standard close-range pressure while hunting, threatened, protecting the pack, or hostile.

A sheep policy permits Bite only when cornered or protecting young. Its normal response to a predator is Flee.

A capybara policy also reserves Bite for desperation or protection.

A gorgon may Bite at close range, but usually favors Stone Gaze at clear midrange or Tail Sweep while surrounded.

A Gremlin treats Bite as ordinary melee pressure and can use its existing enemy-action resource as an execution adapter.

## Species definitions

A `MobSpeciesDefinition` contains:

- Optional parent species for variant inheritance
- Canonical body-plan ID
- Taxonomy tags
- Body tags and anatomy counts
- Locomotion tags
- Ecology tags
- Structured ecology profile
- Base stats and senses
- Default continuous personality traits
- Move policies
- Familiar eligibility
- Familiar progression profile

The first seed species deliberately cover different behavior families:

### Wolf

Pack predator with Bite, Pounce, Pack Howl, Flee, and Idle policies.

### Sheep

Social grazing prey animal. Grazes while safe, flees from predators, and uses Headbutt or Bite only when cornered or protecting young.

### Capybara

Social wetland grazer. Prefers grazing, wading, resting, and retreating toward water. Bite is defensive rather than routine.

### Bear family

One shared Bear profile supplies quadruped anatomy, personality, moves, stats, and familiar progression. Brown Bear, Black Bear, Polar Bear, and Panda inherit it while overriding only their distinctive tags, habitat, statistics, and temperament. Polar Bear demonstrates additive swimming anatomy and locomotion.

## Ecology and habitat compatibility

`MobEcologyProfile` keeps habitat survival separate from movement capability. It records:

- Scale band
- Air, water, or no breathing requirement
- Diet and activity-cycle tags
- Social structure
- Whether one actor represents an individual, group, swarm, colony, or multipart creature
- Required, alternative, preferred, and forbidden habitat tags
- Temperature limits
- Typical home range

A creature may therefore swim without breathing water, as a Goose or Polar Bear does, while Trout requires water as both its locomotion medium and breathing medium. Sessile actors can require aquatic substrate without receiving artificial walking data.

Species can evaluate a dictionary-shaped habitat context and return viability, preference, breathing match, preferred-tag matches, and actionable failures. The live Wilds habitats now publish their media, terrain, climate, and temperature. Cypress Goose and Trout, Woodland Gecko, and Ridge Mole prove that authored populations are ecologically valid as well as physically traversable.

The same profile vocabulary already supports future schools, swarms, colonies, and multipart monsters without pretending every visible group is one ordinary animal.

### Gorgon

Territorial mythic monster. Uses Stone Gaze with line of sight, rejects gaze-immune targets, uses Tail Sweep against crowds, and can disengage to restore ideal range.

### Gremlin

Social scavenger monster with Bite, Pounce, Backstep, Mire Spit, and Idle. Gremlin moves bridge to the existing live `EnemyActionOption` resources.

## Decision context

A `MobDecisionContext` describes the current moment rather than permanent creature identity:

- Target distance
- Self and target health ratios
- Ally and enemy counts
- Current level
- Context, self, and target tags
- Allowed or equipped moves
- Recent moves
- Active cooldowns
- Additional scalar values such as urgency

Example context tags include:

- `safe`
- `hostile`
- `hunting`
- `threatened`
- `cornered`
- `protecting_young`
- `predator_near`
- `water_near`
- `line_of_sight`
- `target_stationary`
- `crowded`
- `surrounded`
- `target_vulnerable`
- `pack_scattered`

The vocabulary can expand without changing the evaluator.

## Personality

The generic personality layer currently uses continuous values from zero to one:

- Aggression
- Courage
- Curiosity
- Sociability
- Territoriality
- Protectiveness
- Patience

The previous enemy-personality profiles remain useful through `MobPersonalityAdapter`:

- Balanced
- Cautious
- Bold
- Skittish
- Brute
- Opportunist

A species supplies its natural baseline. A profile and individual overrides specialize it.

A skittish wounded wolf may flee even though wolves are normally aggressive. A bold sheep becomes more willing to use its conditional defensive attacks, but those attacks still require the sheep policy's situational permission.

## Eligibility and utility

`MobMoveEvaluator` performs two separate steps.

### Eligibility

The evaluator rejects moves that violate hard constraints, including:

- Missing body capabilities
- Unequipped movepool
- Insufficient level
- Active cooldown
- Invalid range
- Health, ally, or enemy bounds
- Missing required tags
- Forbidden tags

### Utility scoring

Eligible moves receive a deterministic score from:

- Move base utility
- Species policy weight
- Personality influence
- Context bonuses
- Recent-use repetition penalty
- Urgency

The result includes both rejection reasons and score reasons for debugging. The highest eligible move is selected.

The evaluator chooses intent only. It does not own navigation, animation, hitboxes, projectiles, or effects.

## Attachable brain component

`MobBrainComponent` can be added to an actor and configured with:

- Species ID
- Previous personality-profile ID
- Individual personality overrides
- Optional familiar progression
- Context provider
- Decision interval
- Recent-move memory

It can:

- Request a ranked decision
- Emit the selected move
- Begin one committed move and start its cooldown
- Advance startup, active, and recovery phases
- Report impact windows, completion, and interruption
- Block new selection while an action is active
- Penalize immediate repetition
- Resolve trained familiar move data
- Return an existing execution adapter when one is available
- Expose detailed debug state

A context-provider node may implement `get_mob_decision_context()` to translate perception, ecology, combat, or familiar orders into generic context data.

## Move execution lifecycle

`MobMoveExecutionState` turns authored timing into a reusable runtime contract. It tracks startup, active, recovery, completion, and interruption without owning animation, navigation, or payload delivery.

`MobBrainComponent` owns at most one active execution. Callers can begin, advance, complete, or interrupt a move and receive signals for phase changes and outcomes. Ordinary interruption respects the move's authored phase policy; forced interruption remains available for death, despawn, reset, or other authoritative state changes.

The live `GenericAnimalActor` uses this lifecycle, so a slow Graze or committed Pounce is no longer replaced by a fresh utility decision every brain tick. Execution aliases such as Investigate or Follow Grace remain adaptations of the selected shared move, not parallel movesets.

## Execution adapters

The Mob Engine does not require every species to use the same actor implementation.

A selected move may be executed by:

- Existing `EnemyActionOption` and enemy-action resources
- A generic animal animation driver
- A monster-specific ability controller
- A familiar command controller
- A boss phase script
- An ambient behavior executor

The existing Gremlin Bite, Backstep, Pounce, and Mire Spit resources remain available through `CreatureAbilityCatalog` as compatibility adapters.

Wolf, sheep, and capybara run through the reusable `GenericAnimalActor`, including committed movement, physical move-effect dispatch, vitals, perception, relationships, and bonding. Gorgon and Gremlin definitions remain valid inputs for specialized or future generic actor presentation.

## Familiar progression

`MobProgressionService` stores one JSON-safe profile per familiar-eligible species.

Each profile contains:

- Version
- Species ID
- Level
- Experience
- Learned moves
- Equipped moves
- Move ranks
- Move augments
- Personality-training overrides

The initial familiar profiles support four equipped moves and five prototype levels.

Level thresholds and move unlock levels live in the species definition. The progression service can therefore support different growth rates and movepools without species-specific leveling code.

## Move ranks

Moves can define generic scaling properties.

The current scaling vocabulary includes:

- Damage per rank
- Stance damage per rank
- Movement distance per rank
- Area radius per rank
- Status buildup per rank
- Status duration per rank

Ranks currently range from one to five.

## Move augments

Augments patch generic move properties rather than replacing the move with a bespoke subclass.

The first augment catalog includes:

### Ferocious

Multiplies direct damage.

### Guard Breaker

Adds stance damage.

### Quickened

Reduces cooldown.

### Venomous

Adds a Poison status rider to compatible attacks.

### Wide Arc

Increases area or sweep radius.

### Long Reach

Extends range.

### Wetting

Adds a Wet primer to compatible projectile or Water actions.

### Steadfast

Improves compatible defensive or recovery duration.

Compatibility is determined by move tags. Bite can accept Ferocious and Venomous, but rejects the projectile-oriented Wetting augment.

The patch engine supports nested property paths and can later add new operations, targeting changes, conditional follow-ups, elemental conversions, animation variants, reaction hooks, or species-specific mutations.

## Relationship to Species Knowledge

The existing `SpeciesKnowledge` service and Mob progression answer different questions.

Species Knowledge records what Grace has learned about a species through observation and research.

Mob progression records how one familiar species has been trained, leveled, equipped, and augmented.

A later integration pass can use knowledge ranks to unlock familiar training options without merging the two stores into one dictionary.

## Automated validation

Scene:

`res://scenes/tests/mob_engine_foundation_smoke_test.tscn`

Expected output:

`MOB_ENGINE_FOUNDATION_SMOKE_TEST: PASS`

The regression verifies:

- Shared move identity across species, including reusable Beak-gated Peck
- Fourteen catalog entries, including one shared Bear parent and four inherited matrix variants
- Canonical body-plan validation across vertebrates, invertebrates, amorphous actors, sessile life, and mythic composites
- Anatomy-count inheritance and species overrides
- Frog, Octopus, Anemone, and membrane-glider structural probes
- Air- and water-breathing habitat compatibility
- Climate and habitat rejection with actionable failure reasons
- Individual, coordinated-group, swarm, colony, and multipart representation metadata
- Wilds population viability across water, surface, and burrow habitats
- Ground, swimming, flight, glide, climbing, and burrowing capability resolution
- Anatomy rejection and locomotion alias normalization
- Runtime ground/swimming/flight/climbing/burrowing mode transitions, direct air-water transitions, and medium rejection
- Planar, surface, and volumetric steering; current sampling; buoyancy; adhesion; waypoint guidance; and gravity handoff
- Opt-in modifier dependencies and transition cleanup
- Generic-animal integration through established water volumes and generic traversal media
- Authored Goose, Trout, Gecko, and Mole definitions without species-specific brain or locomotion classes
- Compatible and incompatible traversal placement, route progress, medium exit, and reset behavior
- Exactly-once active-phase effect claims
- Startup interruption without an effect
- DamagePayload conversion and confirmed projectile delivery
- Species-derived health, stamina, recovery, and incapacitation
- Timed condition application, refresh, expiry, policy tags, control states, movement modifiers, and damage-over-time fallback
- Primary and additional payload-status retention
- Authoritative target providers and range filtering
- Exactly-once contact and area payload delivery
- Physical projectile spawning through `GenericProjectile`
- In-flight projectile ownership and reset cleanup
- Executor memory and reset behavior
- Wolf standard Bite behavior
- Sheep Flee and conditional Bite behavior
- Capybara habitat behavior and defensive Bite
- Gorgon Stone Gaze, gaze immunity, and Tail Sweep
- Previous personality-profile adaptation
- Individual personality specialization
- Familiar experience and levels
- Automatic move learning
- Equipped movepools
- Move ranks
- Generic property augments
- JSON-safe familiar profiles
- Attach-and-query brain component
- Cooldowns and move memory
- Legacy Gremlin execution adapters
- Continued compatibility with every established game regression

A reusable watchdog guarantees the smoke test exits with a readable failure when a runtime script error interrupts the test body.

## Foundation boundaries

The foundation provides shared data, policies, anatomy and locomotion capability profiles, evaluation, personality bridging, familiar progression, augmentation, committed move lifecycles, normalized effect requests, target resolution, physical effect dispatch, payload conversion, vitals, canonical timed statuses, debugging, and compatibility adapters.

Runtime layers already build perception, relationships, bonding, navigation-aware following, rescue, and a reusable live animal actor on top of it. That actor consumes shared ground, swimming, flight, climbing, and burrowing steering; automatically participates in established water and traversal media; follows authored habitat guidance; and reports active locomotion state to move policy. Current limitations are tracked in [`MOB_ENGINE.md`](MOB_ENGINE.md).

The remaining foundation-to-content work is deliberately physical and authored:

- Animation-owned contact volumes for actors that need greater precision than active-phase reach
- An authored exploration-space application of the canonical water and traversal-medium contracts
- Ceiling and corner orientation only when a real climbing route requires them
- Terrain-occluded tunnels, natural entrances/exits, and deformation only when a real burrow encounter requires them
- Finished exploration habitats and encounters that reuse Goose, Trout, Gecko, Mole, and amphibious contracts
- Species-specific models, animation sets, habitats, and encounters
- Provider-specific faction, predator/prey, herd, pack, and summon relation rules
- Broader ecology such as nesting, migration, territory, aging, and life cycles

Those systems consume the shared contracts; they should not replace the brain, moveset, locomotion catalog, locomotion executor, or payload pipeline.
