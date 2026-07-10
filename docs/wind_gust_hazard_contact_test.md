# Wind Gust Hazard Contact Test

## Goal

Make Wind Gust hazard interactions easier to confirm and more reliable.

The suspected issue was not the reaction logic itself. Fire Field and Poison Cloud already know how to react to an air/force payload. The fragile part was likely contact detection: Wind Gust is a short-lived cone burst, while hazards are ground fields with their own Area3D children.

This pass keeps the existing reactions but gives Wind Gust two ways to find hazards:

1. Physics overlap through `GustArea`.
2. A backup scan of nodes in the `hazard_reactive` group.

That means Wind Gust can stir nearby hazards even if the one-frame area overlap misses.

## Changed behavior

Wind Gust now records and displays better debug data:

- `targets`: payload targets found.
- `hazards`: reactive hazards found by overlap and group scan.
- `stirred`: hazards that actually received the wind payload.
- `scan`: labels for hazards found nearby.
- `last`: the last hazard result.

Wind Gust also has two new tuning fields:

- `hazard_scan_group = "hazard_reactive"`
- `hazard_scan_extra_radius = 1.0`

The extra radius only applies to hazards, not enemy hits. This makes hazard chemistry easier to trigger without making Wind Gust hit enemies from farther away.

## Test branch

`agent/wind-gust-hazard-contact-v1`

## Test setup

Use the usual dev scene.

Good scenarios:

- `Fire Field` then `Wind Gust`
- `Poison Cloud` then `Wind Gust`
- `Poison Cloud` then `Fire Field` then `Wind Gust`

## Expected results

### Wind Gust + Poison Cloud

Expected:

- UI should show `Wind Gust stirs Poison Hazard.`
- Poison Cloud should show `Cloud Spread! Wind blooms the poison cloud wider.`
- Poison Cloud radius/lifetime should visibly increase.

### Wind Gust + Fire Field

Expected:

- UI should show `Wind Gust stirs Fire Hazard.`
- Fire Field should show `Fanned Flames! Wind fattens the fire field.`
- Fire Field radius should increase and flare visually.

## Dev Vision checks

On the Wind Gust debug entry, check:

- `hazards` should be greater than 0 if a Fire Field or Poison Cloud exists nearby.
- `scan` should list a hazard label.
- `stirred` should be greater than 0 when the hazard is inside the cone.
- `last` should say which hazard was stirred.

If `hazards > 0` but `stirred = 0`, the gust saw the hazard but the hazard was outside the cone or too far away.

If `hazards = 0`, the hazard either is not in `hazard_reactive`, was already gone, or was too far from the scene scan path.

## Notes

This does not migrate hazard reactions into the combo registry yet. It is a contact/debug pass for the existing hazard scripts.

A later pass can move hazard-to-hazard reactions into `ComboRuleRegistry` once contact is obviously reliable.
