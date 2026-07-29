# Spellcasting Traditions, Mastery, and Achievement Ledger v0.2

## Purpose

Grace does not choose one permanent magic class. She gradually masters several relationships with magic while retaining one shared spell library.

The system separates two axes:

```text
Element   = what power a spell touches
Tradition = how Grace reaches and expresses that power
```

A Fire spell remains one `AbilityDefinition`, but its metadata may make it compatible with Sorcery, Wizardry, Druidry, Warlock practice, Artifice, Ritualism, or another casting context.

## Development taxonomy

The first eight traditions are:

1. **Sorcery**: bloodline and instinct.
2. **Wizardry**: study, analysis, preparation, and deliberate shaping.
3. **Druidry**: communion with living systems and the physical world.
4. **Warlock**: reciprocal covenant with a patron.
5. **Theurgy**: devotion, protection, service, and shared conviction.
6. **Bardic Magic**: sound, rhythm, performance, memory, and emotion.
7. **Artifice**: crafted objects, devices, storage, and mechanisms.
8. **Ritualism**: symbols, ingredients, timing, space, and preparation.

These are stable development IDs. Final in-world names may change without changing save data or gameplay references.

## Story baseline

A new journey begins with:

```text
Sorcery  •  Initiation
Wizardry •  Initiation
```

This reflects Grace being a sorcerer by bloodline and a wizard by study. The baseline is restored after a new-run reset and when loading an older save that predates spellcasting mastery.

Other traditions begin uninitiated.

## Mastery stages

Every tradition advances through four ordered milestones:

```text
Initiation → Practice → Trial → Mastery
```

Each milestone has an achievement-shaped ID:

```text
spellcasting.warlock.initiation
spellcasting.warlock.practice
spellcasting.warlock.trial
spellcasting.warlock.mastery
```

Normal advancement cannot skip stages. Debug tooling may fill earlier stages to preserve a valid sequence.

## Achievement ledger

Spellcasting milestones use the existing `GameState` unlock save path rather than a second progression file.

The storage key is namespaced:

```text
achievement::spellcasting.warlock.mastery
```

The semantic requirement ID remains:

```text
spellcasting.warlock.mastery
```

`GameState.has_unlock()` recognizes both forms. Existing systems can therefore ask for the readable semantic ID while the save ledger keeps achievements isolated from ordinary permissions, key items, spells, and modifiers.

Every definition and stored row declares:

```text
persistence_scope = save_slot
```

Mastery belongs to Grace's current journey. A later platform bridge may mirror selected milestones into account-level achievements without changing story progression.

## Warlock Mastery and Divine Incarnation

Warlock Mastery activates the implemented capstone:

```text
divine_incarnation
```

Ruvia's avatar definition already requires:

```text
required_unlock_id = "spellcasting.warlock.mastery"
```

The shared avatar manager continues to permit debug access to Ruvia in debug builds. A production-style request with debug bypass disabled remains locked until Warlock Mastery is present in the save-slot achievement ledger.

This connects the progression idea to the existing stable-avatar proxy without duplicating incarnation state.

## Spell compatibility

`SpellcastingTraditionResolver` reads existing `AbilityDefinition` metadata:

- element;
- ability category;
- roles;
- combo tags;
- status tags;
- UI tags;
- debug tags;
- scaling tags;
- delivery and targeting metadata.

Sorcery and Wizardry are baseline-compatible with every learned spell. Other traditions become compatible through element, category, and tags.

Explicit metadata can amend automatic resolution:

```text
tradition:artifice
tradition_block:warlock
tradition_only:ritualism
```

Underscore forms are also accepted.

Compatibility is descriptive in v0.2. It does not yet change cost, cast time, targeting, animation, or payload behavior.

## Field Kit integration

Open the Field Kit and choose **Magic**.

Below the spell library, the new **Spellcasting Traditions** section displays all eight traditions with:

- relationship description;
- current stage and rank;
- four milestone markers;
- compatible learned spells;
- capstone name and state;
- story-baseline labeling for Sorcery and Wizardry.

The summary reports initiated traditions, mastered traditions, unlocked milestones, and active capstones.

### Debug controls

Debug builds add three tiles to the Magic tab:

```text
Advance Warlock
Master All
Reset Mastery
```

`Advance Warlock` unlocks one ordered stage at a time. `Master All` completes every tradition silently for systems testing. `Reset Mastery` clears mastery progress and restores the Sorcery/Wizardry story baseline.

These controls are not shown in release builds.

## Ownership

```text
scripts/progression/spellcasting_tradition_catalog.gd
scripts/progression/achievement_catalog.gd
scripts/progression/achievement_service.gd
scripts/progression/spellcasting_mastery_service.gd
scripts/abilities/spellcasting_tradition_resolver.gd
scripts/ui/full_menu_shell_mastery.gd
scripts/tests/spellcasting_mastery_test_fixture.gd
```

The established paths remain stable:

```text
scripts/systems/game_state.gd
scripts/ui/full_menu_director.gd
```

Their mature prior implementations live in `game_state_core.gd` and `full_menu_director_core.gd`, while the stable entry paths add the cross-system mastery integration.

## Automated validation

The focused regression is:

```text
scenes/tests/spellcasting_mastery_smoke_test.tscn
```

It checks:

- eight traditions and 32 milestones;
- save-slot achievement scope;
- Sorcery and Wizardry story baseline;
- ordered Warlock progression;
- namespace isolation from unrelated unlocks;
- semantic requirement lookup through `GameState`;
- production-style Ruvia access before and after Warlock Mastery;
- active Divine Incarnation capstone state;
- achievement capture and restoration;
- automatic, blocked, and exclusive spell compatibility;
- Magic-tab tradition rendering;
- debug master-all and baseline-preserving reset.

Expected Output-panel marker:

```text
SPELLCASTING_MASTERY_SMOKE_TEST: PASS
```

The existing Divine Incarnation regression remains responsible for avatar swapping, restoration, watchdog, and expiry behavior.

## Manual review in Godot

1. Run any scene using the standard player and Game UI.
2. Open the Field Kit with `Tab` or `M`.
3. Choose **Magic**.
4. Confirm Sorcery and Wizardry show **Story Baseline** and **Initiation**.
5. Confirm the other six traditions begin uninitiated.
6. Confirm learned spells appear under compatible traditions.
7. Find Warlock and confirm its capstone is **Divine Incarnation**.
8. In a debug build, use **Advance Warlock** four times.
9. Confirm the milestone track advances in order.
10. Confirm Divine Incarnation becomes active at Mastery.
11. Close the menu and press `F9` to exercise Ruvia through the existing debug control.
12. Reopen the menu, use **Reset Mastery**, and confirm only Sorcery and Wizardry Initiation remain.
13. Save after earning mastery, reload, and confirm the milestones return.

## Deliberate boundaries

- Tradition-specific casting modifiers are not implemented yet.
- Authored Practice requirements and Trial encounters are not implemented yet.
- Final achievement titles and final in-world tradition names are not locked.
- Platform or profile-wide achievement mirroring is not implemented.
- Patron relationship state, invocation assists, and autonomous god summons remain future layers.
- Divine Incarnation still uses the diagnostic wire presentation and Ruvia's prototype kit.
