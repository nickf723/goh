# Mechanism Network v1

Mechanism Network v1 is the reusable puzzle-signal layer for Grace of Humanity.

It complements the existing physical electrical circuit simulation rather than replacing it. A physical pressure plate can close a conductive loop and simultaneously act as a boolean puzzle input. Element sensors, levers, familiar tasks, recorded objects, contraptions, and future detectors can use the same signal contract.

## Signal contract

Every signal source exposes:

```gdscript
signal mechanism_signal_changed(
    mechanism_id: String,
    active: bool,
    packet: Dictionary
)

func get_mechanism_id() -> String
func is_mechanism_active() -> bool
func get_mechanism_packet() -> Dictionary
```

The required semantic value is `active`. Packets provide optional provenance and debug information such as element, source type, timer state, occupant count, counter progress, stored memory state, or sequence progress.

## Core nodes

### `MechanismSignalNode`

Base signal graph node.

- binds sources through exported paths or runtime `bind_source()` calls
- stores per-source state and packets
- emits normalized signal packets
- supports GameState flag persistence
- provides reset and debug contracts

### `MechanismManualSource`

Programmatic input source.

- direct active/inactive state
- toggle
- timed pulse

### `MechanismSourceAdapter`

Wraps an existing mechanic without rewriting it.

- listens to an arbitrary source signal
- reads an arbitrary boolean property or boolean signal argument
- optionally inverts the result

### `MechanismLogicNode`

Supported stateless operations:

- PASS
- AND
- OR
- NOT
- XOR

Supported temporal and stateful operations:

- TIMER
- LATCH
- COUNTER
- TOGGLE
- SET_RESET
- SEQUENCE

Timers trigger on rising edges and sleep when idle. Latches remember that a pulse occurred until reset. Counters advance on rising edges and activate at a configured target.

TOGGLE is a one-bit memory cell: every rising edge flips the stored output. SET_RESET assigns authored source IDs to separate set and reset commands, with optional reset dominance. SEQUENCE compares rising-edge source IDs against an authored order, exposes current progress and the next expected input, and activates when the complete order is entered.

Sequence wrong-input behavior can be authored as:

- `RESET`: clear all progress
- `IGNORE`: preserve current progress
- `RESTART_IF_FIRST`: treat the first step as the beginning of a new attempt

Every memory operation participates in the same reset, packet, debug, output-adapter, and active-state persistence contracts as ordinary boolean gates.

### `MechanismOutputAdapter`

Routes a signal into a world output.

The preferred output contract is:

```gdscript
func set_mechanism_active(active: bool, packet: Dictionary = {}) -> void
```

The adapter can also call separate active/inactive methods or set a boolean property.

## Reusable hardware

### Inputs

- `PressurePlateSwitch`
  - existing physical pressure plate
  - any accepted physics body can press it
  - now emits the shared mechanism signal directly
- `MechanismToggleLever`
  - toggled or momentary interaction input
- `MechanismElementSensor`
  - accepts configured elemental DamagePayload values
  - Fire is the default activation element
  - Water is the default reset element
  - supports latched or momentary behavior

### Outputs

- `MechanismIndicator`
- `MechanismSlidingGate`
- `MechanismBridgeOutput`

All outputs support reset and debug contracts.

## Playable lab

```text
res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn
```

Stations:

1. Weight plate directly opens a gate.
2. Pressure plate AND Fire sensor open a gate.
3. Lever OR Fire sensor extend a bridge; the same lever feeds a NOT indicator.
4. Lever XOR Fire drives a dedicated indicator.
5. A momentary lever opens a timed gate for five seconds.
6. Three lever pulses feed a counter, Fire feeds a latch, and COUNTER AND LATCH open a gate.
7. One momentary lever toggles a remembered state and gate on alternating presses.
8. Separate SET and RESET levers control one stored bit, with RESET dominance.
9. Three labeled inputs form an ordered A → C → B sequence lock; a wrong input clears progress.

F8 or the entrance reset lever restores all inputs, boolean state, memory cells, sequence progress, timers, counters, crates, gates, bridges, and indicators.

## Authoring patterns

### Boolean gate

```gdscript
var and_node := MechanismLogicNode.new()
and_node.operation = MechanismLogicNode.Operation.AND
add_child(and_node)
and_node.bind_source(pressure_plate)
and_node.bind_source(fire_sensor)
```

### Toggle memory

```gdscript
var toggle_memory := MechanismLogicNode.new()
toggle_memory.operation = MechanismLogicNode.Operation.TOGGLE
add_child(toggle_memory)
toggle_memory.bind_source(momentary_lever)
```

### Set/reset memory

```gdscript
var memory := MechanismLogicNode.new()
memory.operation = MechanismLogicNode.Operation.SET_RESET
memory.set_source_ids = Array[String]([set_lever.get_mechanism_id()])
memory.reset_source_ids = Array[String]([reset_lever.get_mechanism_id()])
memory.reset_dominates_set = true
add_child(memory)
memory.bind_source(set_lever)
memory.bind_source(reset_lever)
```

### Ordered sequence

```gdscript
var sequence := MechanismLogicNode.new()
sequence.operation = MechanismLogicNode.Operation.SEQUENCE
sequence.sequence_source_ids = Array[String]([
    input_a.get_mechanism_id(),
    input_c.get_mechanism_id(),
    input_b.get_mechanism_id(),
])
sequence.sequence_wrong_input_behavior = (
    MechanismLogicNode.SequenceWrongInputBehavior.RESET
)
add_child(sequence)
sequence.bind_source(input_a)
sequence.bind_source(input_b)
sequence.bind_source(input_c)
```

### Output

```gdscript
var output := MechanismOutputAdapter.new()
add_child(output)
output.bind_source(sequence)
output.bind_target(gate)
```

Scene-authored networks may instead populate `source_paths` and `target_path`.

## Persistence policy

Use persistence for durable puzzle conclusions:

- permanently opened shortcuts
- one-time counters
- latched dungeon seals
- completed combination locks
- completed secret mechanisms

Do not persist transient physical state:

- a body currently standing on a plate
- remaining timer duration
- an unfinished sequence attempt
- a temporary bridge pulse

`MechanismSignalNode.persist_active_state` writes the resolved active state to a GameState flag. The explicit `persistence_flag` should be stable across scene refactors. For SEQUENCE, active-state persistence remembers completion rather than every partial input.

## Compatibility roadmap

Natural future inputs:

- familiar Hold tasks
- Recorded Object mass
- Artificer power relays
- conductive circuit energized state through `MechanismSourceAdapter`
- sound resonance sensors
- proximity and motion sensors
- water, ice, lightning, and force detectors

Natural future outputs:

- elevators
- rotating platforms
- valves
- traps
- turrets
- conveyors
- environmental transformations

Natural future signal transforms:

- delayed activation and delayed release
- edge-only pulse shaping
- analog thresholds and weighted sums
- multi-bit selectors and decoders
- reusable reset buses for authored puzzle wings

## Regression

```text
res://scenes/tests/mechanism_network_smoke_test.tscn
```

The regression covers every boolean, temporal, and memory operation; physical pressure-plate bridging; elemental payload sensing; output hardware; collision changes; sequence failure behavior; reset behavior; and the complete production lab structure.
