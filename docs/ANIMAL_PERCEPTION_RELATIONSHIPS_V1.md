# Animal Perception and Relationships v1

## Purpose

This layer replaces the Animal Behavior Lab's omniscient threat toggle with actual sensory state and gives every live animal a persistent opinion of Grace.

The animal brain now receives context from three different timescales:

1. **Perception** describes what the creature currently sees or hears.
2. **Memory** preserves a last-known position after the stimulus disappears.
3. **Relationship** records how repeated interactions with Grace change trust and fear association.

## Perception memory

`AnimalPerceptionMemory` is configured from species stats and resolved personality traits.

It tracks:

- Sight range
- Hearing range
- Species-shaped field of view
- Current visual detection
- Current auditory detection
- Last seen position
- Last heard position
- Last known position
- Remaining memory duration
- Awareness
- Stimulus kind
- Social alert position and severity

The first species use different view cones:

- Sheep have very wide prey-animal vision with a narrow rear blind spot.
- Capybaras have broad peripheral awareness.
- Wolves have a narrower forward-facing predator cone.

A physics ray verifies line of sight. Moving Grace produces ordinary movement noise, while the lab can emit a stronger explicit disturbance.

## Memory

Seeing or hearing Grace refreshes a timed memory. When Grace leaves sight, the animal retains the last known location and receives `remembers_grace` context rather than instantly becoming ignorant.

The live executor uses that memory to:

- Continue fleeing away from the remembered threat position
- Continue pursuing a hostile target briefly
- Investigate a heard noise or recently observed peaceful visitor
- Remain alert while sensory certainty fades

Memory duration is influenced by patience and courage. Cautious animals generally retain uncertain danger longer.

## Pack alerts

Animals may broadcast a perceived threat to nearby members of the same species.

The initial lab demonstrates this with Ash and Cinder:

- One wolf sees or strongly detects threatening Grace.
- The detecting wolf broadcasts the last-known position and alert severity.
- The second wolf receives a social perception memory even without direct sight.
- The alert adds territorial pressure and can unlock Pack Howl, hunting, or regrouping behavior.

This is the first reusable bridge toward herd alarms, flock reactions, sentries, predator calls, and coordinated monster groups.

## Relationship state

`AnimalRelationshipState` stores values independent of immediate drive pressure:

- Trust from -1 to 1
- Familiarity from 0 to 1
- Fear association from 0 to 1
- Peaceful exposure time
- Last interaction
- Interaction count

The relationship is currently local to the live actor. A later persistence pass can serialize named or bonded animals into save data.

## Relationship labels

The numeric relationship and current fear drive resolve into one readable state:

- Hostile
- Afraid
- Wary
- Neutral
- Curious
- Trusting

Aggressive creatures with low trust tend toward Hostile. High current fear or fear association produces Afraid. Repeated calm exposure and positive interactions gradually move an animal through Neutral and Curious toward Trusting.

## Peaceful habituation

When Grace remains visible at a respectful distance and moves calmly:

- Familiarity slowly increases.
- Trust slowly increases according to curiosity and patience.
- Fear association decays.

Invading personal space before trust is established can reverse that progress. Species, courage, and current trust determine comfort distance.

## Direct interactions

The first relationship interactions are:

### Feed

- Strongly increases trust and familiarity
- Reduces fear association
- Satisfies hunger

### Soothe

- Moderately increases trust and familiarity
- Strongly reduces fear and fear association
- Reduces social pressure

### Startle

- Reduces trust
- Creates a strong fear association
- Spikes the fear drive
- Creates a remembered threat position
- Broadcasts an alert to nearby same-species animals

The interaction API also reserves `attack` and `help` events for later gameplay integration.

## Ambient investigation

No new universal move definition is required for the first investigation pass. The live execution adapter interprets an eligible Idle decision as `Investigate` when the animal:

- Heard a disturbance
- Received a social alert
- Sees Grace while Curious, Trusting, or cautiously Wary

This preserves the shared move catalog while allowing Idle to remain a species-specific ambient action.

## Lab controls

The Animal Behavior Lab no longer depends on raw letter or number keys.

Its on-screen panel includes mouse-clickable and controller-focusable controls for:

- Previous and next animal selection
- Grace's peaceful or threatening posture
- Feed
- Soothe
- Startle
- Make Noise
- Drive-pressure debug buttons
- Clear Drives
- Reset Lab

The normal restart input remains supported.

## Debug readouts

The selected-animal panel and overhead labels now expose:

- Relationship label
- Trust
- Familiarity
- Current stimulus
- Awareness
- Memory duration
- Intention and action
- Core drives

## Automated validation

Scene:

`res://scenes/tests/animal_perception_relationship_smoke_test.tscn`

Expected output:

`ANIMAL_PERCEPTION_RELATIONSHIP_SMOKE_TEST: PASS`

The regression verifies:

- Visual detection inside the view cone
- Timed memory after Grace leaves sight
- Nearby feeding and persistent trust growth
- Curious relationship resolution
- Startle-driven fear and Afraid relationship resolution
- Hearing a disturbance without sight
- Wolf-to-wolf alert sharing
- Territorial pressure from a pack alert

The existing live Animal Behavior Lab regression also verifies that the redesigned lab builds its on-screen button panel and retains physical Graze and Flee execution.
