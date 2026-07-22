# Aerial Traversal and Flight Concentration v1

## Scene

`res://scenes/levels/prototypes/prototype_aerial_traversal_lab_v1.tscn`

## Goal

Validate one shared aerial locomotion controller across Double Jump, Hover, Flight, landing, concentration reservation, action restrictions, and controlled descent.

## Controls

- Move: left stick or WASD
- Camera: right stick or mouse
- Jump / Double Jump / Ascend: Jump
- Hover: hold Jump near the apex after the Double Jump
- Descend during Flight: Dodge
- Activate or dismiss Flight: Cast
- Reset laboratory: F8 in the editor

## Expected progression

1. Begin without Flight active.
2. Jump from the launch deck and press Jump again in the air.
3. Confirm the second press gives one strong additional impulse.
4. Hold Jump as the Double Jump approaches its apex.
5. Confirm Grace transitions into a brief, controllable Hover rather than snapping motionless.
6. Cross the Hover Gap and land on the marked platform.
7. Cast Flight.
8. Confirm maximum mana 12 becomes 3 usable and 9 reserved.
9. Move horizontally with the left stick while the camera remains independent.
10. Hold Jump to ascend.
11. Hold Dodge to descend.
12. Release both vertical controls and confirm Grace brakes toward a stable altitude.
13. Fly through the numbered rings and the Precision Arch.
14. Attempt weapon attacks, ordinary casting, interaction, Dodge, and Soul Grip. They should remain blocked during Flight I.
15. Reach and land on the Crown Beacon platform.
16. Cast Flight again to dismiss it.
17. Dismiss Flight while airborne and confirm Grace enters a controlled descent rather than an unrestricted fall.
18. Confirm the full mana ceiling returns but missing mana must regenerate normally.
19. Press F8 and confirm the player, concentration, goal, and traversal state reset.

## Feel review

Judge these before adding upgrades:

- Horizontal acceleration should feel responsive without instantly reversing momentum.
- Neutral vertical input should hold altitude without constant button feathering.
- Ascend and descend should feel symmetrical and predictable.
- Camera movement must not secretly steer vertical movement.
- Double Jump should preserve horizontal intent.
- Hover should feel like a bridge to Flight rather than miniature Flight.
- Precision movement through the arch should be comfortable on controller.
- Landing and dismissing Flight should never produce a sudden downward spike.

## Known limitations

- Flight I is movement-only. Aerial combat, spellcasting, Soul Grip, items, interaction, and aerial Dodge are deferred to upgrades.
- Flight has no stamina cost, boost, dash, banking animation, or speed tiers yet.
- Hover duration is a fixed prototype value rather than a progression stat.
- Rings are visual route markers rather than scored checkpoints.
- The chamber uses procedural geometry and temporary presentation.
