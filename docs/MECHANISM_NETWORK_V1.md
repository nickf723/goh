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

The required semantic value is `active`. Packets provide optional provenance and debug information such as element, source type, timer state, occupant count, or counter progress.

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

Supported operations:

- PASS
- AND
- OR
- NOT
- XOR
- TIMER
- LATCH
- COUNTER

Timers trigger on rising edges. Latches remember a pulse until reset. Counters advance on rising edges and activate at a configured target.

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
4. A momentary lever opens a timed gate for five seconds.
5. Three lever pulses feed a counter, Fire feeds a latch, and COUNTER AND LATCH open the final gate.

F8 or the entrance reset lever restores all inputs, logic memory, timers, counters, crates, gates, bridges, and indicators.

## Authoring pattern

```gdscript
var and_node := MechanismLogicNode.new()
and_node.operation = MechanismLogicNode.Operation.AND
add_child(and_node)
and_node.bind_source(pressure_plate)
and_node.bind_source(fire_sensor)

var output := MechanismOutputAdapter.new()
add_child(output)
output.bind_source(and_node)
output.bind_target(gate)
```

Scene-authored networks may instead populate `source_paths` and `target_path`.

## Persistence policy

Use persistence for durable puzzle conclusions:

- permanently opened shortcuts
- one-time counters
- latched dungeon seals
- completed secret mechanisms

Do not persist transient physical state:

- a body currently standing on a plate
- remaining timer duration
- a temporary bridge pulse

`MechanismSignalNode.persist_active_state` writes to a GameState flag. The explicit `persistence_flag` should be stable across scene refactors.

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

## Regression

```text
res://scenes/tests/mechanism_network_smoke_test.tscn
```

The regression covers every logic operation, physical pressure-plate bridging, elemental payload sensing, output hardware, collision changes, reset behavior, and the complete production lab structure.
