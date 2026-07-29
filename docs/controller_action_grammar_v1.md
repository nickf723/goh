# Controller Action Grammar v1.2

This document defines the authoritative player-facing controller grammar after the first direct implementation pass.

## Design rules

1. One physical control has one stable player-facing meaning.
2. Context reuse is allowed only when the contextual meaning remains physically related.
3. Attacks never participate in chords or tap-versus-hold delays.
4. One shoulder pair owns weapons and the opposite pair owns magic.
5. The two shoulder pairs can be mirrored as a complete handedness preset.
6. D-pad tap-versus-hold gestures are reserved for actions where a short recognition delay is acceptable.
7. Browsing and activation are separate operations.
8. Controller, keyboard, HUD prompts, settings, and regressions should read from one authoritative binding layer.

## Default preset: combat right, magic left

| Control | Meaning |
|---|---|
| Left stick | Move |
| Right stick | Camera or selection inside the active radial/menu |
| Left-stick click | Crouch |
| Right-stick click | Lock on |
| A / right face | Interact or confirm |
| B / bottom face | Dodge, descend, drop, back, or cancel |
| X / top face | Jump or ascend |
| Y / left face | Guard or contextual exertion |
| R | Light attack |
| ZR | Heavy attack |
| L | Hold Focus and open the full spell-selection layer |
| ZL | Cast selected spell |
| D-pad Up tap | Cycle quick item |
| D-pad Up hold | Use selected quick item |
| D-pad Left / Right | Cycle the three favorited quick spells |
| D-pad Down tap | Attempt to activate the selected Divine Special |
| D-pad Down hold | Open the Divine Special selector |
| Plus | Unified full menu |
| Minus | Reserved |

## Mirrored preset: combat left, magic right

The mirrored preset swaps complete shoulder pairs rather than remapping four unrelated actions.

| Control | Mirrored meaning |
|---|---|
| L | Light attack |
| ZL | Heavy attack |
| R | Hold Focus |
| ZR | Cast selected spell |

The internal grammar remains identical:

```text
Bumper = quick or setup action
Trigger = committed or powerful action
```

F4 switches between the two presets in debug builds. A persistent settings-menu option remains future work.

## D-pad grammar

### Outside Focus

```text
Up tap       Cycle quick item
Up hold      Use selected quick item
Left         Previous favorited quick spell
Right        Next favorited quick spell
Down tap     Activate selected Divine Special if ready
Down hold    Browse Divine Specials
```

The three quick-spell favorites initially resolve to the first three equipped spells. Selection is immediate and persistent, while casting still uses the magic-hand trigger.

### Inside Focus

While the magic bumper is held, the D-pad changes context and belongs entirely to the full spell browser:

```text
Left / Right   Previous or next element
Up / Down      Previous or next spell in that element
```

The right stick offers the same navigation. D-pad quick items, quick spells, and Divine Specials are suppressed until Focus closes.

### Quick items

D-pad Up uses a `0.28` second threshold:

```text
Release before threshold   Cycle to the next equipped item
Cross the hold threshold   Begin using the selected item once
Release after use begins   Do not also cycle
```

The item keeps its authored drink, throw, or activation duration after the input gesture resolves.

### Divine Specials

Selection is deliberately separate from activation:

```text
Tap Down                 Attempt to activate the selected Special
Hold Down                Open the selector at any charge level
Right stick              Change the selected unlocked Special
Release after holding    Keep the selection and close without activating
B / Circle               Cancel the selector without changing charge
```

A player may therefore organize the next Divine Special while the meter is still recharging. Changing or confirming a selection never consumes charge. Only a later quick tap attempts activation.

## Context grammar

### Ground combat

- A interacts.
- B dodges.
- X jumps.
- Y guards.
- The combat-hand bumper and trigger perform Light and Heavy attacks.
- The magic-hand bumper opens Focus and the trigger casts.
- D-pad Left and Right rotate through favorite spells outside Focus.
- D-pad Up cycles or uses quick items outside Focus.
- D-pad Down owns Divine Special activation and selection outside Focus.

### Swimming

- X ascends.
- B descends.
- Y swims faster.
- A interacts with water-context objects.

### Flight

- X ascends.
- B descends.
- Y may later boost or brake.
- Recasting the active Flight spell may release concentration.

### Climbing

- Movement controls climbing direction.
- X jumps away or mantles when valid.
- B drops.
- Combat and loadout actions remain suppressed unless a later traversal upgrade explicitly permits them.

### Riding

- A mounts, dismounts, or interacts.
- X jumps.
- Y gallops.
- Shoulder hand roles remain stable for mounted combat and magic.

### Stealth

- Left-stick click toggles crouch.
- A performs a contextual takedown when valid, otherwise it interacts normally.

### Menus and dialogue

- A confirms.
- B cancels or backs out.
- D-pad and left stick navigate.
- Shoulder buttons may change tabs only inside paused menus.

## Implemented architecture

`WeaponInputBootstrap` owns the shoulder preset and D-pad action bindings. It installs `PlayerControlRouter`, whose contextual extension routes the D-pad into Focus navigation while Focus is open.

The Divine Special router owns only D-pad Down outside Focus. It allows selection at incomplete charge and separates held-radial release from quick-tap activation.

## Regression contract

The controller regressions verify:

- both hand-role presets;
- removal of hidden legacy controller bindings;
- Focus hold and release;
- D-pad and right-stick Focus navigation;
- three-spell quick-ribbon cycling;
- quick-item tap-versus-hold behavior;
- Divine selection while recharging;
- selection-only held-radial release;
- low-charge tap rejection;
- full-charge tap activation exactly once;
- controller-device isolation;
- attack preservation;
- radial cancellation and time restoration.
