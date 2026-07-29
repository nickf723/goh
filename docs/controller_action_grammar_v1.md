# Controller Action Grammar v1.1

This document inventories the current player actions and defines the controller grammar for the next input refactor.

## Design rules

1. One physical control has one stable player-facing meaning.
2. Context reuse is allowed only when the meaning still feels related.
3. Attacks never participate in chords or tap-versus-hold delays.
4. The shoulders are divided by hand role: one hand owns weapons and one owns magic.
5. The weapon-hand and magic-hand shoulder pairs can be mirrored as a complete accessibility preset.
6. Tap-versus-hold gestures belong only on actions where a short recognition delay is acceptable.
7. Runtime scripts must not silently rewrite bindings owned by other systems.
8. Controller, keyboard, HUD prompts, settings, and tests must read from one authoritative binding catalog.

## Current controller map

| Control | Current action | Contextual actions |
|---|---|---|
| Left stick | Move | Climb, swim, fly, ride |
| Right stick | Camera | Focus radial selection, Divine Special selection, lock-on target switching |
| Left-stick click | Crouch toggle | None |
| Right-stick click | Lock on | None |
| A / right face | Interact | Dialogue confirm, mount or dismount, stealth takedown |
| B / bottom face | Dodge | Cancel, swim or flight descend, drop from climb |
| X / top face | Jump | Swim or flight ascend, mount jump, climb jump |
| Y / left face | Guard | Perfect Guard, swim sprint, mount gallop |
| L | Light attack | Dialogue history |
| R | Heavy attack | None |
| ZL | Focus spell menu | None |
| ZR | Cast selected spell | Release sustained Flight when Flight remains selected |
| L + R | Divine Special | Tap activates; hold opens radial |
| D-pad Up | Quick item Up | Focus spell navigation |
| D-pad Left | Quick item Left | Focus element navigation |
| D-pad Right | Quick item Right | Focus element navigation |
| D-pad Down | Special context tap or wheel | Focus spell navigation |
| Plus | Full menu | Close full menu |
| Minus | Quest journal | Close journal |

## Current conflicts and inconsistencies

### Attack chord

L and R are immediate attacks but also form the Divine Special chord. The router must cancel attacks, refund stamina, distinguish sequential combos from simultaneous input, and handle failed charge checks. This is a large mechanical tax for one gesture.

### Duplicate contextual ownership

Interact, RidingController, and SpecialContextController all own portions of mounting, dismounting, animal study, familiar commands, and nearby contextual behavior. D-pad Down therefore duplicates work that already belongs conceptually to Interact.

### D-pad mismatch

The quick belt contains four slots, but the controller removes D-pad Down from the fourth item slot at runtime so Special Context can use it. The HUD and data model describe four controller slots while the player can directly access only three.

### Hidden runtime remapping

The project InputMap includes a face-button Light Attack binding. PlayerDefenseController removes that event at runtime and assigns the same physical button to Guard. The editor map, documentation, prompts, and runtime can therefore disagree.

### Keyboard collisions

- `J` is both Light Attack and Quest Journal.
- `Tab` is both Full Menu and Special Context.
- `R` is both Next Ability and Restart Scene, though defeat state limits the collision.
- `C` is Dodge and Flight Descend, which is acceptable because the meanings align contextually.
- `H` is quick healing and dialogue history, which is acceptable only while dialogue fully captures input.

### Menu fragmentation

Full Menu and Quest Journal are separate paused interfaces on Plus and Minus even though the journal can naturally be a tab inside the full menu.

## Recommended final controller map

### Default preset: combat right, magic left

| Control | Recommended meaning |
|---|---|
| Left stick | Move |
| Right stick | Camera or current radial selection |
| Left-stick click | Crouch |
| Right-stick click | Lock on |
| A / right face | Interact or confirm; hold for contextual command wheel |
| B / bottom face | Dodge, descend, drop, or cancel |
| X / top face | Jump or ascend |
| Y / left face | Guard or exertion action such as sprint, gallop, or flight boost |
| R | Light attack |
| ZR | Heavy attack |
| L | Hold Focus and open the full spell-selection layer |
| ZL | Cast selected spell |
| D-pad Up tap | Cycle to the next quick item |
| D-pad Up hold | Use the selected quick item |
| D-pad Left | Select the previous favorited quick spell |
| D-pad Right | Select the next favorited quick spell |
| D-pad Down tap | Activate the selected Divine Special |
| D-pad Down hold | Open the Divine Special radial; release to activate |
| Plus | Unified full menu |
| Minus | Reserved for a future map, photo mode, or accessibility shortcut |

### Mirrored preset: combat left, magic right

The preset swaps the complete shoulder pairs rather than remapping individual actions independently.

| Control | Mirrored meaning |
|---|---|
| L | Light attack |
| ZL | Heavy attack |
| R | Hold Focus and open the full spell-selection layer |
| ZR | Cast selected spell |

This preserves the same internal grammar on either side:

```text
Bumper = quick or setup action
Trigger = committed or powerful action
```

On the combat hand, the bumper is Light Attack and the trigger is Heavy Attack. On the magic hand, the bumper opens Focus and the trigger casts.

## D-pad loadout grammar

### Quick items on Up

D-pad Up belongs exclusively to quick items.

```text
Tap Up                 Cycle to the next equipped quick item
Hold Up past threshold Use the currently selected quick item once
Release after use      Do not also cycle
```

Recommended hold threshold: `0.28` seconds. Quick-item use may begin as soon as the threshold is crossed. The item itself can retain its existing drinking, throwing, or activation duration.

The HUD should show one selected item prominently, with its quantity, and briefly reveal the neighboring belt entries after a tap. The underlying belt may still contain four or more configured items even though the controller exposes one active selection.

### Favorited spells on Left and Right

D-pad Left and Right navigate a small quick-spell ribbon rather than the full spell library.

```text
Tap Left   Select the previous favorited spell
Tap Right  Select the next favorited spell
```

The quick ribbon should initially contain three player-configured favorites. Selection is immediate and persistent. Casting still occurs through the magic-hand trigger, so navigating the ribbon never spends mana or accidentally casts.

The full Focus interface remains available for browsing every learned spell, changing elements, inspecting spell details, and replacing quick favorites. The ribbon is for repeatedly using a compact combat loadout without reopening the library.

### Divine Specials on Down

D-pad Down belongs exclusively to Divine Specials.

```text
Tap Down                 Activate the currently selected Divine Special
Hold Down past threshold Open the Divine Special radial
Right stick              Select an unlocked Special
Release Down             Activate the highlighted Special
B                         Cancel without spending charge
```

Divine Specials no longer touch weapon input, stamina refunds, or attack startup cancellation.

## Context grammar

### Ground combat

- A interacts.
- B dodges.
- X jumps.
- Y guards.
- The combat-hand bumper and trigger perform Light and Heavy attacks.
- The magic-hand bumper opens Focus and the trigger casts.
- D-pad Left and Right rotate through three favorited spells.
- D-pad Up cycles or uses quick items.
- D-pad Down owns Divine Specials.

### Swimming

- X ascends.
- B descends.
- Y swims faster.
- A interacts with contextual water objects.
- Shoulder hand roles remain stable if combat or spell use is permitted in water.

### Flight

- X ascends.
- B descends.
- Y boosts or brakes once flight depth needs that action.
- Recasting the active Flight spell may still release concentration.
- Shoulder hand roles remain stable.

### Climbing

- Movement controls climbing direction.
- X jumps away or mantles when valid.
- B drops.
- Combat, Focus, casting, quick items, and Divine Specials are suppressed unless a later traversal ability explicitly permits them.

### Riding

- A mounts, dismounts, or interacts.
- X jumps.
- Y gallops.
- B may become an emergency dismount only if playtesting needs one.
- Shoulder hand roles remain stable for mounted combat and magic.

### Stealth

- Left-stick click toggles crouch.
- A performs a contextual takedown when one is valid; otherwise it interacts normally.
- Shoulder hand roles remain stable so stealth attacks and magic do not require a separate control vocabulary.

### Menus and dialogue

- A confirms.
- B cancels or backs out.
- D-pad and left stick navigate.
- Shoulder buttons may change tabs only inside paused menus.
- Plus opens one full menu containing the Journey or Quest tab.

## Recommended refactor order

### Pass 1: Single source of truth and handedness preset

Create one binding catalog or input director that owns action names, keyboard keys, mouse buttons, controller buttons, prompt labels, and the selected handedness preset. Remove cross-system event deletion and ad hoc InputMap mutation.

### Pass 2: Rebuild the shoulder grammar

For the default preset, bind R to Light Attack, ZR to Heavy Attack, L to Focus, and ZL to Cast. Add the mirrored preset as a complete pair swap. Remove the old shoulder-chord route from Divine Specials.

### Pass 3: Rebuild the D-pad grammar

- Up becomes one tap-or-hold quick-item action.
- Left and Right navigate the three-slot quick-spell ribbon.
- Down owns the existing tap-or-hold Divine Special interface.

Delete the old four-direction quick-item controller bindings and the old Focus D-pad navigation assumptions after the replacements are functional.

### Pass 4: Merge contextual actions into Interact

Tap A performs the primary interaction. Holding A opens commands only when a familiar, mount, study target, or other contextual system supplies options. Remove the standalone `special_context` binding.

### Pass 5: Unify paused menus

Move the quest journal into the full menu and reserve Minus. Remove the separate controller action and eliminate the keyboard `J` collision.

### Pass 6: Regression contract

Verify every physical control in both handedness presets across ground combat, Focus, quick spells, quick items, Divine Specials, dialogue, swimming, flight, climbing, riding, stealth, and paused menus. Tests should assert the final runtime map rather than only checking that actions exist.

## First implementation slice

The first implementation slice should combine Pass 1 and the smallest part of Pass 2:

1. Introduce the authoritative binding catalog with `combat_right_magic_left` and `combat_left_magic_right` presets.
2. Move Light, Heavy, Focus, and Cast to the selected shoulder pair.
3. Move Divine Special to D-pad Down while preserving its existing tap, hold, radial, cancel, and release behavior.
4. Remove shoulder attack conversion and stamina refund behavior.

Quick-item and quick-spell D-pad behavior should follow in the next slice so each gesture can receive focused regression coverage.