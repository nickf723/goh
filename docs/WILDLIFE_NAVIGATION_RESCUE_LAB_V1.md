# Wildlife Navigation and Rescue Lab v1

## Purpose

This dedicated lab moves the named-animal loop off the flat relationship floor and into a compact encounter course with real collision geometry, dynamic navigation baking, an injured trapped animal, a physical food pickup, weapon-compatible damage, and companion recovery.

Run:

`res://scenes/levels/prototypes/wildlife_navigation_rescue_lab_v1.tscn`

The lab uses the normal Grace player scene and Game UI. All special test controls are mouse-clickable and controller-focusable.

## Encounter

Juniper is a cautious named sheep with the stable identity:

`wildlife_navigation_lab:juniper`

She begins:

- Injured
- Trapped behind debris
- Unable to leave the rescue pen
- Wary of Grace
- Eligible to remember trust and harm across reloads

The intended loop is:

1. Collect the glowing Field Treat basket.
2. Approach the rescue pen.
3. Clear the debris.
4. Heal Juniper.
5. Feed her until the bond requirements are met.
6. Bond with her.
7. Walk through the S-shaped obstacle course.
8. Test the raised ramp and lookout.
9. Test Follow / Stay, forced repathing, severe separation, saving, reloading, and harm consequences.

## Runtime navigation

`NavigationBondedAnimalActor` extends the bonded animal actor with a `NavigationAgent3D`.

The agent:

- Refreshes its target as Grace moves.
- Calls `get_next_path_position()` during physics movement.
- Uses the returned waypoint instead of steering directly through walls.
- Tracks path point count, target reachability, path queries, repaths, stuck time, and recoveries.
- Requests a fresh path after prolonged lack of progress.
- Reunites near Grace only after severe separation or prolonged obstruction.

The lab bakes a `NavigationMesh` from its static collision geometry at runtime.

The source includes:

- The rescue pen
- Removable debris
- Boundary walls
- Two offset maze walls forming an S path
- A sloped ramp
- A raised lookout

Removing the rescue debris triggers a second bake so the pen becomes connected to the main walkable region.

## Rescue and healing

The debris can be cleared through the panel or the normal Interact action while standing near the pen.

Rescue:

- Removes the blocking collider.
- Unlocks Juniper's movement.
- Reports a `rescue` event to the relationship layer.
- Rebakes the navigation mesh.

Healing:

- Reduces the injury ratio.
- Reports a `heal` event.
- Raises trust and lowers fear.
- Removes the injured movement penalty when the injury is sufficiently treated.

## Field Treat pickup

The glowing basket is a physical `Area3D` pickup.

Collecting it grants four real `Field Treat` inventory items. Feeding Juniper consumes one item per successful interaction.

The panel can respawn the basket without resetting the encounter or relationship.

## Real damage bridge

The navigation-aware animal implements:

`receive_damage_payload(payload)`

This matches the weapon controller's payload receiver contract. A normal weapon swing can therefore strike Juniper through her existing body collision.

A hit:

- Reports an `attack` relationship event.
- Lowers trust.
- Raises fear.
- Marks Juniper injured.
- Increments persistent harm history.
- Returns normal combat feedback text.

The **Test Attack** button invokes the same bridge without requiring a weapon swing.

## Chase bridge

A fast close sprint behind a rescued Juniper can be interpreted as a chase.

The lab checks:

- Grace's planar speed
- Distance to Juniper
- Whether Grace is behind Juniper
- A cooldown preventing repeated event spam

A detected chase reports the existing `chase` relationship event.

## Command and harm interruption

Animal moves now have a shared startup, active, and recovery lifecycle. Issuing Follow, Stay, Come Here, or Go There is authoritative: it interrupts Juniper's current ambient move before applying the command. A weapon hit, Test Attack, or detected chase also interrupts the current action so fear and escape behavior can respond immediately.

Manual check:

1. Wait until Juniper begins an ambient or grazing action.
2. Issue a companion command and confirm the named command replaces that action immediately.
3. While she is moving under a command, use **Test Attack** and confirm the command suspends and the active move gives way to the fear response.
4. Lower fear and confirm the stored command resumes through the existing command-authority rules.

## Recovery

The companion attempts an ordinary repath before teleport recovery.

Recovery occurs only when:

- Grace is farther than the configured severe-separation distance, or
- The animal has failed to make progress for several seconds

The recovery destination is projected to the closest point on the active navigation map near Grace.

The **Separate Grace** button deliberately creates this situation.

## Debug panel

The panel exposes:

- Navigation readiness
- Baked polygon count
- Bake count
- Rescue and injury state
- Current action
- Bond and Follow / Stay state
- Field Treat inventory
- Trust, familiarity, and fear memory
- Path point count
- Navigation query count
- Repath count
- Recovery count
- Current stuck duration
- Last lab event

## Automated validation

Scene:

`res://scenes/tests/wildlife_navigation_rescue_lab_smoke_test.tscn`

Expected output:

`WILDLIFE_NAVIGATION_RESCUE_LAB_SMOKE_TEST: PASS`

The regression verifies:

- Runtime navigation baking
- Walkable polygons
- Trapped and injured starting state
- Physical Field Treat inventory pickup
- Rescue relationship consequences
- Debris removal and navigation rebaking
- Healing consequences
- Inventory-backed feeding
- Bond eligibility and bonding
- NavigationAgent3D physics queries
- A multi-point route around static walls
- Physical distance-closing through the obstacle course
- Weapon-compatible damage consequences
- Persistent harm history
- Severe-separation recovery
- Named bond saving

## Current limits

- The lab uses one named sheep rather than a full herd.
- Rescue and healing have panel controls in addition to world interaction hooks.
- Navigation recovery is intentionally conservative but still teleports when ordinary pathing cannot reasonably reunite the companion.
- Dynamic moving obstacles are not yet using RVO avoidance.
- Jump links and authored off-mesh traversal are not included in this first pass.
