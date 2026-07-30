# Spell Targeting Preview Framework v1

## Purpose

Every spell should communicate where it will act before the player commits resources. The preview is presentation and validation only. Payload delivery, damage, status effects, summons, terrain changes, and combo consequences remain owned by their existing gameplay systems.

The shared flow is:

```text
Ability metadata
    → SpellTargetingCatalog
    → SpellTargetingProfile
    → SpellTargetingPreview
    → valid or invalid placement
    → cast confirmation
```

A spell may provide an authored `SpellTargetingProfile`, runtime overrides, or only its existing `targeting_style` and `delivery_type`. Missing information is inferred, while authored information wins.

## Supported preview shapes

| Shape | Intended uses | Main dimensions |
|---|---|---|
| Point | precise placement, teleport destination, interactable point | range |
| Circle | ground AoE, persistent fields, traps, summons | radius, range |
| Cone | breath, fan attacks, sound bursts, gusts | length, angle |
| Line | beams, walls, piercing attacks, lanes | length, width |
| Trajectory | thrown or arcing projectiles | range, endpoint, arc |
| Self Burst | splashdown, defensive pulse, transformation burst | radius |
| Target Lock | single-target spells and homing effects | range, line of sight |

`NONE` is reserved for abilities that should never show a targeting preview.

## Placement modes

- `FREE_GROUND`: right-stick cursor constrained to terrain and range.
- `FORWARD`: shape projects from Grace in the facing or aim direction.
- `SELF`: preview remains centered on Grace.
- `TARGET`: preview follows a selected valid receiver.
- `BALLISTIC`: preview draws an arc from source to endpoint.

## Profile contract

A `SpellTargetingProfile` can describe:

- maximum and minimum range
- radius, length, width, and cone angle
- initial cursor distance and cursor speed
- ground, obstruction, and line-of-sight requirements
- range clamping
- valid, invalid, and neutral colors
- fill and outline opacity
- pulse behavior and emission
- whether to show the source range ring, direction guide, and center marker

Profiles validate themselves before targeting starts. Invalid profiles fail closed rather than producing a malformed cast state.

## Input ownership

Only one mode may own the right stick at a time:

```text
Normal play        camera or lock-on
Focus library      element and spell browsing
Ground targeting   target cursor
Divine selector    Divine Special selection
```

Ground targeting is a modal casting state but is not the visible Focus library. Beginning an AoE placement hides Focus and prevents the Focus bumper or D-pad from reopening it underneath the cursor.

## Validity language

The preview is shown in the spell or element color while valid and shifts to the shared invalid red when placement fails.

Initial invalid reasons include:

- no stable ground under the target
- outside maximum range
- inside minimum range
- blocked line of sight when the profile requires it

Invalid confirmation does not spend Mana, trigger the cast lock, or dismiss the targeting mode. The player can correct the placement and try again.

## Current migration

The first clients are the existing ground spells:

- Earth Spike
- Poison Bloom / Poison Cloud
- Time Snare
- Dream Trap / Dream Snare

Their effects and payloads remain unchanged. Their anonymous marker dictionaries are converted at runtime into circle profiles, preserving authored radius, range, speed, color, pulse, and cast-lock values.

## Authoring paths

### Legacy ability

Existing `AbilityDefinition` resources continue to work. The catalog infers a preview from:

```text
targeting_style
delivery_type
element
runtime targeting configuration
```

### Explicitly targeted ability

New abilities that need full control may use `TargetedAbilityDefinition` and assign a `SpellTargetingProfile` resource.

Runtime configuration may still override authored fields for upgrades or temporary modifiers. Precedence is:

```text
runtime override
    > authored targeting profile
    > ability metadata inference
    > framework defaults
```

Explicit colors and dimensions are never overwritten by element defaults.

## Performance rules

- Preview geometry is constructed when targeting begins, not every frame.
- Materials are reused while the target moves.
- Cursor updates change transforms, dynamic guide vertices, pulse scale, and color state only.
- Gameplay effect queries are not performed by the renderer.
- Future target-count estimates should use throttled queries rather than per-frame receiver scans.

## Next integrations

The next safe consumers are:

1. Fire Field and other placed hazards using circle profiles.
2. Sound or Air fan attacks using cone profiles.
3. Lightning or Water beams using line profiles.
4. Thrown gadgets and arcing spells using trajectory profiles.
5. Divine Special battlefield previews using the same shapes at larger scale.

The framework should remain descriptive. A new spell should usually add data, not a bespoke preview controller.
