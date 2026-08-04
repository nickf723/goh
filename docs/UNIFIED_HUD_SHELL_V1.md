# Unified HUD Shell v1

## Goal

Replace the accumulation of independently positioned gameplay panels with one mode-aware layout authority.

The shell does not own gameplay state. Existing systems keep their managers, signals, and command contracts. The shell owns where their presentation appears, how competing messages are prioritized, and which lanes are suppressed during modal gameplay.

## Six layout zones

### Status cluster

Top-left. Grace's identity and survival resources live here.

- health
- mana
- stamina
- stance
- future compact status icons

### Mode banner

Top-center on wide displays. On narrow and compact displays it moves into a dedicated second row beneath the top corner clusters.

- current objective
- placement mode
- recorded-object proving-ground context
- other high-level gameplay modes

### Activity rail

Top-right.

- tracked progression
- discoveries
- achievements
- blueprint recordings
- ordinary system messages

Only a small number of transient cards remain visible simultaneously.

### Action bar

Bottom-center.

- quick item
- ten quick spells
- divine special
- authoritative equipped-spell state

The existing command dock is reparented into this zone rather than replaced.

### Support cluster

Bottom-right on wide displays. It moves above the action deck at narrow widths.

- Grace portrait
- familiar command state
- reproduced objects
- Artificer drafts
- deployed contraptions
- compact gameplay status

### Context strip

Directly above the action bar.

- interaction prompts
- placement validity
- manipulation instructions
- temporary contextual controls

## HUD modes

The shell resolves one presentation mode from authoritative gameplay state.

### Exploration

All normal zones may appear.

### Placement

- activity rail hidden
- support cluster hidden
- action bar dimmed
- mode banner and context strip become placement authorities

### Focus

- spell library owns attention
- activity and support zones hidden
- gameplay HUD dimmed

### Ability context

- persistent ability menu owns attention
- lower-priority HUD zones hidden

### Dialogue

Gameplay HUD is suppressed behind the dialogue surface.

## Publication API

Systems publish presentation data without positioning their own panels.

```gdscript
hud.publish_mode(source_id, data, priority)
hud.clear_mode(source_id)

hud.publish_context(source_id, data, priority, duration_seconds)
hud.clear_context(source_id)

hud.publish_activity(
    kind,
    title,
    body,
    duration_seconds,
    source_id,
    priority,
    major,
    current,
    target
)

hud.set_tracked_activity(data)
hud.set_active_ability_entries(entries, highlighted_id)
```

Higher-priority mode and context publications temporarily win their lane without deleting lower-priority state.

## Retired duplicate surfaces

The underlying systems remain active, but these standalone renderers are hidden when the unified shell is present:

- old persistent-ability ribbon
- compact familiar/context status card
- shared-placement private panel
- standalone divine-special panel
- legacy progression toast renderer
- Recorded Object lab's private top-right status panel
- legacy objective, prompt, and center-message labels

## Responsive breakpoints

### Wide, 1500 pixels and above

The top row uses three columns: status, mode, activity.

### Narrow, 900 to 1499 pixels

Status and activity remain in the first row. The mode banner receives a second row. Support moves above the bottom deck.

### Compact, below 900 pixels

Status and activity use reduced corner widths. The mode banner remains centered in a dedicated second row. Support stays above the action/context deck.

The source bridge is the final geometry authority each frame so child presenters cannot silently reclaim old coordinates.

## Regression

Run:

```text
res://scenes/tests/unified_hud_shell_smoke_test.tscn
```

The regression verifies:

- all six zones exist
- action dock is parented to the action-bar zone
- top and bottom lanes do not overlap
- objectives, prompts, and messages route to shared lanes
- persistent abilities route to support
- placement and Focus suppress the correct zones
- retired duplicate surfaces remain hidden
- normal exploration presentation returns after modal modes close
