# Controller Action Grammar v1

This document inventories the current player actions and defines a simpler controller grammar for the next input refactor.

## Design rules

1. One physical control has one stable player-facing meaning.
2. Context reuse is allowed only when the meaning still feels related.
3. Attacks never participate in chords.
4. Focus is the only gameplay modifier layer.
5. Runtime scripts must not silently rewrite bindings owned by other systems.
6. Controller, keyboard, HUD prompts, and tests must read from one authoritative binding catalog.

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
| L | Light attack |
| R | Heavy attack |
| ZL | Hold Focus and open the spell-selection layer |
| ZR | Cast selected spell |
| D-pad Up | Use selected quick item |
| D-pad Left | Previous quick item |
| D-pad Right | Next quick item |
| D-pad Down | Divine Special: tap selected Special, hold radial, release to activate |
| Plus | Unified full menu |
| Minus | Reserved for a future map, photo mode, or accessibility shortcut |

## Context grammar

### Ground combat

- A interacts.
- B dodges.
- X jumps.
- Y guards.
- L and R attack.
- ZL and ZR own magic.
- D-pad Down owns Divine Specials without touching attacks.

### Swimming

- X ascends.
- B descends.
- Y swims faster.
- A interacts with contextual water objects.

### Flight

- X ascends.
- B descends.
- Y boosts or brakes once flight depth needs that action.
- Recasting the active Flight spell may still release concentration.

### Climbing

- Movement controls climbing direction.
- X jumps away or mantles when valid.
- B drops.

### Riding

- A mounts, dismounts, or interacts.
- X jumps.
- Y gallops.
- B may become an emergency dismount only if playtesting needs one.

### Stealth

- Left-stick click toggles crouch.
- A performs a contextual takedown when one is valid; otherwise it interacts normally.

### Menus and dialogue

- A confirms.
- B cancels or backs out.
- D-pad and left stick navigate.
- L and R change tabs only inside paused menus.
- Plus opens one full menu containing the Journey or Quest tab.

## Recommended refactor order

### Pass 1: Single source of truth

Create one binding catalog or input director that owns action names, default keyboard keys, mouse buttons, controller buttons, and prompt labels. Remove cross-system event deletion and ad hoc InputMap mutation.

### Pass 2: Remove the attack chord

Move Divine Special to D-pad Down. Delete startup attack conversion, stamina refund, simultaneous timing, and shoulder-device chord state. Keep the existing tap, hold, radial, cancel, and release behavior.

### Pass 3: Merge contextual actions into Interact

Tap A performs the primary interaction. Holding A opens commands only when a familiar, mount, study target, or other contextual system supplies options. Remove the standalone `special_context` binding.

### Pass 4: Simplify quick items

Replace four directional item actions with `quick_item_use`, `quick_item_previous`, and `quick_item_next`. Preserve the four-slot belt data if desired, but expose one selected item through the controller.

### Pass 5: Unify paused menus

Move the quest journal into the full menu and reserve Minus. Remove the separate controller action and eliminate the keyboard `J` collision.

### Pass 6: Regression contract

Verify every physical control in ground combat, Focus, dialogue, swimming, flight, climbing, riding, stealth, and paused menus. Tests should assert the final runtime map rather than only checking that actions exist.

## First implementation slice

The safest first code change is Pass 2: move Divine Special from L + R to D-pad Down while leaving the rest of the controller unchanged. It immediately removes the most fragile gesture and lets the attack system return to ordinary Light and Heavy input.
