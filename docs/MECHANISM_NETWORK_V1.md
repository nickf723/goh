# Mechanism Network v1

Mechanism Network v1 is the reusable puzzle-signal layer for Grace of Humanity.

It complements the physical electrical-circuit simulation rather than replacing it. Pressure plates, levers, elemental sensors, familiar tasks, recorded objects, contraptions, and future detectors can all speak through the same mechanism contract.

## Signal contract

Every signal source exposes the original Boolean contract:

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

Value-aware sources additionally expose:

```gdscript
func get_mechanism_value() -> float
func get_mechanism_min_value() -> float
func get_mechanism_max_value() -> float
func get_mechanism_normalized_value() -> float
func get_mechanism_value_unit() -> String
```

Every normalized signal packet carries:

```text
active
value
minimum_value
maximum_value
normalized_value
unit
```

Existing Boolean mechanisms remain compatible. By default, Boolean sources mirror OFF and ON to numeric values `0.0` and `1.0`. Numeric sources may change value without forcing their Boolean state to change.

## Core nodes

### `MechanismSignalNode`

Base signal graph node.

- binds sources through exported paths or runtime `bind_source()` calls
- stores per-source Boolean state and value packets
- exposes raw and normalized source values
- atomically applies Boolean state and numeric value
- supports active-state persistence through GameState flags
- provides reset and debug contracts

### `MechanismManualSource`

Programmatic input source.

- direct active/inactive state
- direct numeric value
- toggle
- timed pulse

### `MechanismSourceAdapter`

Wraps an existing mechanic without rewriting it.

- listens to an arbitrary source signal
- reads an arbitrary Boolean property or signal argument
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

### `MechanismValueComparator`

Converts one or two numeric inputs back into a Boolean puzzle signal.

Supported comparisons:

- greater than
- greater than or equal
- less than
- less than or equal
- equal within tolerance
- inside an inclusive range
- outside a range
- two sources within a shared tolerance

A comparator reports its primary value, secondary value, signed difference, threshold, range, tolerance, and readable comparison summary in its signal packet and debug data.

### `MechanismSelectorSource`

Stores a discrete channel selection as both an integer value and a readable label.

- any rising-edge source can advance the selection
- direct assignment supports authored switches, dials, and restored state
- selection may wrap or clamp
- output packets include index, count, label, and controlling source
- reset restores the authored initial channel

### `MechanismRouterNode`

Routes one live input to exactly one of several ordinary mechanism outputs.

- selected output receives the original Boolean state and numeric value
- unselected outputs are cleared immediately
- changing selection while the input remains active transfers power without requiring a new input edge
- each channel is itself a normal `MechanismManualSource`, so existing output adapters remain reusable
- packets retain source provenance and add route/channel metadata

### `MechanismMultiplexerNode`

Chooses one of several inputs and exposes it as one ordinary mechanism output.

- input order is explicitly authored
- selection may control Boolean or numeric sources
- changes from the currently selected source propagate without another selection event
- packets identify the requested index and selected source
- reset returns to the selector's authored initial input

### `MechanismOutputAdapter`

Routes a signal into a world output.

The original Boolean target contract remains:

```gdscript
func set_mechanism_active(
    active: bool,
    packet: Dictionary = {}
) -> void
```

Value forwarding can be enabled on the same adapter:

```gdscript
func set_mechanism_value(
    value: float,
    packet: Dictionary = {}
) -> void
```

Adapters may forward raw or normalized values, then apply an authored scale and offset. Boolean forwarding remains the default, so existing gates and indicators are unchanged.

## Reusable hardware

### Inputs

- `PressurePlateSwitch`
  - movable rigid bodies and `CharacterBody3D` actors can press it
  - static floors and station platforms are ignored by default
  - `AnimatableBody3D` machinery is ignored by default
  - remains a Boolean contact source
  - reports the summed mass of all accepted occupying bodies in kilograms
  - updates its numeric signal when mass changes even if it remains pressed
  - supports explicit mass metadata or a body's own mass contract
  - debug data records rejected body entries to expose collision-authoring mistakes
- `MechanismToggleLever`
  - toggled or momentary interaction input
- `MechanismElementSensor`
  - accepts configured elemental DamagePayload values
  - Fire is the default activation element
  - Water is the default reset element
  - supports latched or momentary behavior
- `MechanismWeightBlock`
  - reusable Soul-Grippable puzzle weight
  - exposes authored mass directly to weighted pressure plates
  - retains collision, mass-scaled Soul Grip movement, and reset behavior

### Outputs

- `MechanismIndicator`
- `MechanismSlidingGate`
- `MechanismBridgeOutput`
- `MechanismValueElevator`
  - maps an authored input range to a movement fraction
  - supports raw-value or packet-range mapping
  - remains collidable while moving as an AnimatableBody3D
  - reports current value, target fraction, and movement state

All outputs support reset and debug contracts.

## Playable lab

```text
res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn
```

### Boolean and timing wing

1. A weight plate directly opens a gate.
2. A pressure plate AND Fire sensor open a gate.
3. A lever OR Fire sensor extend a bridge; the same lever feeds NOT, while lever XOR Fire drives a separate indicator.
4. A momentary lever opens a timed gate for five seconds.
5. Three lever pulses feed a counter, Fire feeds a latch, and COUNTER AND LATCH open the final gate.

### Memory wing

6. One momentary lever toggles a remembered state and gate on alternating presses.
7. Separate SET and RESET levers control one stored bit, with RESET dominance.
8. Three labeled inputs form an ordered `A → C → B` sequence lock; a wrong input clears progress.

### Value Signal wing

9. Three Soul-Grippable blocks weighing 2 kg, 4 kg, and 7 kg feed a mass-reporting plate. A comparator opens the gate at 10 kg or more.
10. Two plates feed a balance comparator. The gate opens when left and right loads differ by no more than 0.1 kg. Both plates must carry weight, so `0 kg = 0 kg` does not solve the station.
11. A 0–10 kg plate drives a proportional elevator from 0–6 meters. Adding and removing load changes platform height continuously rather than merely switching it on or off.

### Signal Routing wing

12. A selector chooses LEFT or RIGHT. A Soul-Grippable block keeps a pressure plate active while the router transfers the same live signal between two gates and indicators.
13. A three-channel selector chooses LOW, MIDDLE, or HIGH. A multiplexer selects one of three stored floor values and sends it to a proportional lift.

F8 or the entrance reset lever restores all inputs, Boolean state, memory cells, sequence progress, numeric comparisons, selector channels, router outputs, multiplexer selections, timers, counters, weighted blocks, gates, bridges, indicators, and proportional elevators.

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
memory.set_source_ids = Array[String]([
    set_lever.get_mechanism_id(),
])
memory.reset_source_ids = Array[String]([
    reset_lever.get_mechanism_id(),
])
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

### Numeric threshold

```gdscript
var threshold := MechanismValueComparator.new()
threshold.comparison = (
    MechanismValueComparator.Comparison.GREATER_OR_EQUAL
)
threshold.threshold = 10.0
add_child(threshold)
threshold.bind_source(weight_plate)
```

### Balance comparison

```gdscript
var balance := MechanismValueComparator.new()
balance.comparison = (
    MechanismValueComparator.Comparison.SOURCES_WITHIN_TOLERANCE
)
balance.primary_source_id = left_plate.get_mechanism_id()
balance.secondary_source_id = right_plate.get_mechanism_id()
balance.tolerance = 0.1
balance.require_all_sources_active = true
add_child(balance)
balance.bind_source(left_plate)
balance.bind_source(right_plate)
```

### Proportional output

```gdscript
var output := MechanismOutputAdapter.new()
output.forward_value = true
output.value_target_method = &"set_mechanism_value"
output.also_apply_boolean_state = false
add_child(output)
output.bind_source(weight_plate)
output.bind_target(elevator)
```

### One input routed to several outputs

```gdscript
var selector := MechanismSelectorSource.new()
selector.selection_count = 2
selector.selection_labels = Array[String](["LEFT", "RIGHT"])
add_child(selector)
selector.bind_source(change_route_button)

var router := MechanismRouterNode.new()
router.channel_count = 2
add_child(router)
router.bind_input(power_source)
router.bind_selector(selector)

left_output.bind_source(router.get_channel_output(0))
right_output.bind_source(router.get_channel_output(1))
```

### Several values selected for one output

```gdscript
var multiplexer := MechanismMultiplexerNode.new()
multiplexer.selector_source_id = selector.get_mechanism_id()
multiplexer.input_source_ids = Array[String]([
    low_value.get_mechanism_id(),
    middle_value.get_mechanism_id(),
    high_value.get_mechanism_id(),
])
add_child(multiplexer)
multiplexer.bind_selector(selector)
multiplexer.bind_input(low_value)
multiplexer.bind_input(middle_value)
multiplexer.bind_input(high_value)

lift_output.bind_source(multiplexer)
```

Scene-authored networks may instead populate `source_paths` and target paths.

## Persistence policy

Use active-state persistence for durable puzzle conclusions:

- permanently opened shortcuts
- one-time counters
- latched dungeon seals
- completed combination locks
- completed secret mechanisms

Do not persist transient physical or numeric state:

- a body currently standing on a plate
- current supported mass
- remaining timer duration
- an unfinished sequence attempt
- temporary elevator position
- temporary bridge pulse
- a temporary selector position unless the puzzle explicitly requires it

`MechanismSignalNode.persist_active_state` writes the resolved active state to a GameState flag. Numeric values and selector indices remain runtime state in v1. For SEQUENCE, active-state persistence remembers completion rather than every partial input.

## Natural extensions

The shared grammar is ready to support:

- water and fuel levels
- temperature and pressure
- resonance frequency and amplitude
- electrical voltage, current, and stored charge
- distance and proximity
- rotation and alignment
- conveyor, valve, light, and turbine intensity
- weighted sums and arithmetic transforms
- priority overrides
- multi-bit selectors and decoders
- reusable reset buses

Likely next routing extensions include emergency overrides, four-channel decoding, delayed route changes, and authored routing diagrams.

## Regression

Boolean, timing, and memory grammar:

```text
res://scenes/tests/mechanism_network_smoke_test.tscn
```

Numeric values, mass measurement, comparators, proportional output, and the Value Signal wing:

```text
res://scenes/tests/mechanism_value_signal_smoke_test.tscn
```

Soul-Grippable weight behavior:

```text
res://scenes/tests/mechanism_soul_weight_smoke_test.tscn
```

Static pressure-plate filtering, selectors, routers, multiplexers, live route transfer, and the production Routing wing:

```text
res://scenes/tests/mechanism_routing_smoke_test.tscn
```

Together the regressions cover the Boolean, temporal, memory, value, physical manipulation, routing, output, collision, reset, and production-laboratory contracts.
