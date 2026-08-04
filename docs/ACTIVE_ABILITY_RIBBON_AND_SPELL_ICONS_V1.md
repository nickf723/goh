# Active Ability Ribbon and Spell Icons v1

## Purpose

Persistent abilities can remain active while Grace switches to ordinary combat spells. The HUD should show those active systems without forcing the familiar, reproduced objects, and Artificer tools to compete for one status card.

The spell library also needs to distinguish three different ideas:

- the spell being browsed
- the spell assigned to one or more quick slots
- the spell currently equipped for Cast

## Active Ability Ribbon

The player-level ability context router installs one `PlayerActiveAbilityRibbon`.

It gathers active entries from persistent providers. Providers may expose a dedicated entry:

```gdscript
func get_active_ability_ribbon_entry() -> Dictionary
```

Providers that do not implement the dedicated method are adapted from their existing `get_ability_context_status()` result.

The ribbon shows:

- a flat icon badge
- a short label
- the provider's current state
- attention state when relevant
- a gold highlight when the matching persistent spell is equipped

The ribbon hides when nothing persistent is active, while the Focus library is open, or during shared placement.

## Spell icon bridge

`SpellIconFactory` searches the current project for authored spell textures using the spell ID in common Flaticon and spell-icon folders.

Supported temporary roots include:

- `res://art/icons/spells/`
- `res://art/icons/flaticons/`
- `res://art/flaticons/`
- `res://assets/icons/spells/`
- `res://assets/icons/flaticons/`
- `res://assets/flaticons/`
- `res://icons/spells/`

SVG, PNG, and WebP files are supported. A file named `firebolt.svg`, for example, is imported automatically for the `firebolt` spell.

When no texture is available, the factory creates an element-colored flat badge with a readable spell or element glyph. Every spell therefore has a visual identity immediately, while authored Flaticon assets can replace the fallback without another UI rewrite.

## Equipped spell authority

`AbilityCaster.current_ability_index` remains the only authoritative equipped-spell state.

Both selection routes already call `AbilityCaster.select_ability()`:

- selecting a quick spell
- confirming a spell in the Focus library

The updated UI reads that same index:

- The Focus library uses the normal element highlight for the browsed row.
- The equipped row receives a separate gold border and `★ EQUIPPED` marker.
- Quick-slot assignments remain visible as `SLOT 1`, `SLOT 4`, and similar labels.
- The command dock uses gold for the actually equipped quick slot.
- The remembered quick-slot cursor uses blue when it differs from the equipped spell.
- The dock header always names the equipped spell, including spells that are not assigned to any of the ten quick slots.

This prevents a stale quick-slot cursor from pretending an older spell is still equipped after Grace chooses a spell from the full library.

## Controller behavior

No new controls are introduced.

- D-pad Left and Right continue cycling quick spells.
- Focus opens the spell library.
- D-pad or right stick browses the library.
- Cast or A equips the highlighted spell.
- Active persistent entries highlight automatically when their matching spell becomes equipped.
