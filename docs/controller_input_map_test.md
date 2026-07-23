# Canonical Player Control Map

This is the runtime control contract for Grace. Controller labels use Nintendo-style names, with Godot's standard physical positions underneath.

## Controller

| Input | Action |
|---|---|
| Left stick | Move |
| Right stick | Camera / aim |
| `L` | Light attack |
| `R` | Heavy attack |
| `ZL` | Hold Focus spell selector |
| `ZR` | Cast equipped spell / confirm Focus selection |
| Bottom face | Dodge; descend while flying |
| Right face | Interact |
| Top face | Jump; ascend while flying |
| Left face | Reserved |
| D-pad | Navigate Focus; manipulate distance/rotation while Soul Grip is active |
| Right stick click | Lock on |
| Start | Full menu |

Light and Heavy are deliberately a matched shoulder pair. Focus and Cast are deliberately a matched trigger pair. Soul Grip does not own a global controller button.

## Keyboard and mouse

| Input | Action |
|---|---|
| `WASD` | Move |
| Mouse | Camera / aim |
| Left mouse or `J` | Light attack |
| Mouse side button or `K` | Heavy attack |
| Right mouse or `Shift` | Hold Focus spell selector |
| `Q` | Cast equipped spell / confirm Focus selection |
| `Space` | Jump; ascend while flying |
| `C` | Dodge; descend while flying |
| `E` | Interact |
| `T` | Lock on |
| `Tab` or `M` | Full menu |

## Soul Grip

1. Hold Focus.
2. Select **Soul Grip** from the Soul element.
3. Release Focus.
4. Aim at a Soul-marked object and hold Cast.
5. Use D-pad up/down or the mouse wheel to change distance.
6. Use D-pad left/right or `Z`/`X` to rotate.
7. Release Cast to drop the object.

Confirming Soul Grip inside Focus equips it only. The player must release and press Cast again to begin manipulation, preventing an accidental grab while closing the menu.

## Regression test

Run:

`scenes/tests/chain_weapon_smoke_test.tscn`

The test verifies the complete Light/Heavy keyboard, mouse, and controller bindings; rejects right mouse as Heavy; rejects the left face button as Light; confirms Soul Grip is learned through the ability loadout; and confirms Soul Grip cannot remove `L` from Light Attack.
