# Mechanism Priority Overrides and Decoders v1

This layer completes the first routing grammar for the Grace of Humanity mechanism network. It builds directly on Boolean signals, memory, numeric values, selectors, routers, and multiplexers.

## Priority selector

`MechanismPrioritySelector` preserves one normal selection while allowing one or more active override sources to temporarily seize control.

Each override provides:

- a source mechanism ID;
- an output selection value;
- an integer priority; and
- an optional readable label.

The highest active priority wins. Equal priorities resolve deterministically in authored source order. Normal selection continues updating while an override is active, so clearing the override restores the newest normal choice rather than the choice that existed when the override began.

The output packet reports:

```text
selection_index
selection_label
normal_selection_index
normal_selection_label
winning_source_id
winning_priority
winning_label
override_active
```

### Example

```gdscript
var authority := MechanismPrioritySelector.new()
authority.selection_count = 3
authority.selection_labels = Array[String]([
    "LEFT",
    "RIGHT",
    "EMERGENCY",
])
add_child(authority)
authority.bind_normal_source(normal_selector)
authority.bind_override_source(
    fire_sensor,
    2,
    100,
    "FIRE EMERGENCY"
)
```

## One-of-N decoder

`MechanismDecoderNode` converts an address into ordinary mechanism output channels. Every output is a `MechanismManualSource`, so existing gates, indicators, timers, memory nodes, and output adapters can consume decoded channels without decoder-specific hardware.

Address modes:

- `SELECTOR_VALUE`: round the numeric value of a selector or priority selector;
- `BOOLEAN_BITS`: combine authored Boolean sources into a binary address.

For Boolean-bit mode, `first_bit_is_most_significant` determines the authored bit order. The production two-bit station uses:

```text
A B = 00 → AZURE
A B = 01 → GREEN
A B = 10 → AMBER
A B = 11 → VIOLET
```

Invalid-address behavior:

- `CLEAR_OUTPUTS`: no channel is active;
- `CLAMP`: values outside the range select the nearest endpoint;
- `WRAP`: values wrap through the channel count.

A valid address activates exactly one channel. Every other output is cleared during the same evaluation.

### Selector example

```gdscript
var decoder := MechanismDecoderNode.new()
decoder.address_mode = MechanismDecoderNode.AddressMode.SELECTOR_VALUE
decoder.channel_count = 3
decoder.channel_labels = Array[String]([
    "LEFT",
    "RIGHT",
    "EMERGENCY",
])
add_child(decoder)
decoder.bind_selector(authority)
```

### Boolean-bit example

```gdscript
var decoder := MechanismDecoderNode.new()
decoder.address_mode = MechanismDecoderNode.AddressMode.BOOLEAN_BITS
decoder.channel_count = 4
decoder.first_bit_is_most_significant = true
decoder.bit_source_ids = Array[String]([
    bit_a.get_mechanism_id(),
    bit_b.get_mechanism_id(),
])
add_child(decoder)
decoder.bind_bit(bit_a)
decoder.bind_bit(bit_b)
```

## Playable stations

Launch:

```text
res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn
```

### 14: Emergency Override

1. `CHANGE NORMAL ROUTE` chooses LEFT or RIGHT.
2. The priority selector normally forwards that remembered selection.
3. Fire latches the emergency sensor and forces address 2.
4. The emergency decoder closes LEFT and RIGHT and opens only the emergency exit.
5. The normal route can still change while Fire owns control.
6. Water clears the emergency sensor and restores the newest remembered normal route.

### 15: Four-Door Decoder

Two momentary levers toggle two memory bits. The decoder interprets Bit A as the most-significant bit and Bit B as the least-significant bit. Exactly one of AZURE, GREEN, AMBER, or VIOLET remains active.

## Reset contract

F8 or the laboratory reset lever restores:

- normal selectors;
- active elemental overrides;
- priority winners;
- hidden normal selections;
- decoder memory bits;
- decoded addresses;
- every decoded output channel;
- all connected indicators and gates.

After reset, the emergency station returns to normal LEFT control and the four-door station returns to address `00`, with exactly one active output in each station.

## Regression

```text
res://scenes/tests/mechanism_priority_decoder_smoke_test.tscn
```

The regression covers:

- normal priority fallback;
- simultaneous low- and high-priority overrides;
- hidden normal-state changes beneath an override;
- restoration after each override clears;
- selector-address decoding;
- invalid clear, clamp, and wrap behavior;
- two-bit addresses `00`, `01`, `10`, and `11`;
- exactly-one-output behavior;
- both production stations; and
- full laboratory reset.
