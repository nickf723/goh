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

Locomotion is now resolved as a second capability layer. Ground, swimming, flight, climbing, and burrowing are movement modes; runner, serpentine, hover, and jumper are modifiers or transitions. The shared catalog validates anatomy and dependencies, so species can combine modes without introducing species-specific brain code. See [`ANIMAL_BODY_LOCOMOTION_AND_EFFECTS_V1.md`](ANIMAL_BODY_LOCOMOTION_AND_EFFECTS_V1.md).

## Active-phase effects

A committed execution claims one normalized effect request when it first crosses into the active phase. The request preserves targeting, range, radius, effect data, source lineage, and delivery class. Confirmed contact, area, projectile, status, and buff effects convert into the existing `DamagePayload` contract; movement, recovery, and custom effects remain explicit physical-executor seams.

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

- Taxonomy tags
- Body tags
- Locomotion tags
- Ecology tags
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

Wolf, sheep, capybara, and gorgon currently have valid species definitions and decision policies but do not yet have complete live actor/execution adapters.

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

- Shared move identity across species
- Body-plan validation
- Ground, swimming, flight, climbing, and burrowing capability resolution
- Anatomy rejection and locomotion alias normalization
- Exactly-once active-phase effect claims
- Startup interruption without an effect
- DamagePayload conversion and confirmed projectile delivery
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

The foundation provides shared data, policies, anatomy and locomotion capability profiles, evaluation, personality bridging, familiar progression, augmentation, committed move lifecycles, normalized effect requests, payload conversion, debugging, and compatibility adapters.

Runtime layers already build perception, relationships, bonding, navigation-aware following, rescue, and a reusable live ground actor on top of it. Their current limitations are tracked in [`MOB_ENGINE.md`](MOB_ENGINE.md).

The remaining foundation-to-content work is deliberately physical and authored:

- Contact volumes and area target collection
- Projectile spawning and impact confirmation
- Health, stamina, and drive recovery receivers
- Swimming, flight, climbing, and burrowing motion executors
- Species-specific models, animation sets, habitats, and encounters
- Broader ecology such as nesting, migration, territory, aging, and life cycles

Those systems consume the shared contracts; they should not replace the brain, moveset, locomotion catalog, or payload pipeline.
