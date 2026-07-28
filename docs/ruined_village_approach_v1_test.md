# Ruined Village Approach v1.0 Manual Test

Scene:

```text
res://scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn
```

## Purpose

This is the first large outdoor application of the modular environment kit, Authored Set Composer, Grace spatial profile, and spatial-readability rules. It remasters the existing integrated route without changing its story, combat encounter, elemental route solutions, optional Sound memory, checkpoint, persistence, or Church Trial handoff.

## Expected route

```text
Teleport Impact Hollow
→ abandoned weapon cache
→ modular road up the arrival grade
→ outer ruined homes and clues
→ open village square and optional Sound memory
→ Goblin / Gremlin ambush
→ collapsed ravine
   ↙ Water → Ice bridge
   ↘ Fire OR Ice + Heavy debris route
→ church hill
→ church-ground checkpoint
→ Church Trial entrance
```

## 1. Outdoor visual benchmark

From the arrival hollow, verify:

- the road reads as repeated weathered stones embedded in earth rather than one long flat slab;
- the road follows the authored arrival ramp without floating far above it or disappearing into it;
- the armory and crater remain immediately readable;
- the distant church remains the dominant long-range landmark;
- the giant `THE VANISHED VILLAGE`, `VILLAGE SQUARE`, and `ABANDONED ARMORY` development labels are no longer visible;
- olive clusters, fences, ruins, and road edges frame the route without forming a tunnel.

In the outer village, verify:

- the four former primitive house shells are replaced visually by modular façades and ruined corners;
- foundations remain aligned with the new walls;
- the dry well, lifted foundation, empty hearth, cart, and other story-specific landmarks remain bespoke and recognizable;
- low walls and rubble sit outside the protected road lane;
- there are visible quiet gaps between detail clusters.

## 2. Grace and camera space

- Walk and sprint the full road without jumping over visual lips.
- Rotate the camera while passing the façades, fences, well, market stalls, and low walls.
- Confirm Grace's slimmer silhouette remains readable outdoors and does not look stretched.
- Press against every low wall and fence used by the remaster.
- Confirm roads and visual façades do not add duplicate collision over the original support terrain.
- Confirm physical low walls and fences remain solid.
- Confirm decorative rubble and olive clusters do not snag Grace.

## 3. Readability and density

The level protects six routes:

- arrival road;
- main village road;
- left ravine route;
- right ravine route;
- church approach;
- optional Sound-memory path.

It also protects approach space around the three clues, Sound memory, village-square combat area, both elemental crossings, checkpoint, village well, and church landmark.

Judge whether:

- the road remains readable without floating arrows;
- the village square has enough lateral room for dodging and lock-on combat;
- both ravine routes are visible after the encounter barrier opens;
- the optional Sound path feels discoverable but not mandatory;
- the church is visible often enough to anchor orientation;
- vegetation frames views rather than repeatedly blocking them.

For development-only tuning, set `show_debug_zones = true` on `OutdoorRemasterPass`. Green lanes show protected travel space, blue lanes show camera envelopes, amber circles show interactions, violet circles show landmarks, and red circles show combat space. Disable the overlay for ordinary play.

## 4. Existing story and interaction regression

- Inspect the arrival-crater clue.
- Inspect the lifted-foundation clue.
- Inspect the empty-hearth clue.
- Reveal and collect the optional wooden-bird memory using Sound.
- Confirm the new architecture does not obscure any prompt or interaction radius.
- Confirm the clues still update the same objectives and persistent flags.

## 5. Village-square combat

- Trigger the registered two-Goblin, one-Gremlin encounter.
- Test Light and Heavy branches with Sword, Hammer, or Spear.
- Use lock-on, Dodge, a spell, and an elemental reaction.
- Confirm enemies do not become trapped behind the new low walls.
- Confirm the modular ruins do not crowd the combat camera.
- Defeat all enemies and confirm the encounter barricade opens.

## 6. Ravine route solutions

Test each route after a reset or reload.

### Right route

- Use Fire to clear the debris directly, or Ice followed by Heavy/force.
- Cross the existing stone bridge.
- Confirm the modular road branch guides toward the gate but does not overlap its collision.

### Left route

- Apply Water, then Ice, to create the frozen crossing.
- Cross the bridge and climb the left ascent.
- Confirm the route remains visually distinct from the debris bridge.

## 7. Church approach and persistence

- Confirm both ravine routes converge beneath the church hill.
- Follow the four modular road sections toward the church.
- Confirm the church façade, towers, cypress trees, graves, and gold entrance remain bespoke landmarks.
- Use the church-ground checkpoint and verify resources restore.
- Reload after saving and confirm route flags, clue states, encounter completion, Sound memory, and bridge state restore.
- Enter the Church Trial and confirm the destination scene remains:

```text
res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

## Collision ownership

The remaster intentionally separates presentation and support:

- road modules reuse the original terrain and ramp collision;
- ruined façades and corners are presentation over the existing foundation shells;
- hidden legacy foundation meshes retain their proven collision;
- low walls and timber fences own collision;
- rubble and olive clusters are nonblocking dressing.

Any invisible lip, vibration, blocked clue, camera trap, or mismatch between a visible wall and its support foundation is a remaster defect.

## Automated coverage

```text
res://scenes/tests/ruined_village_approach_smoke_test.tscn
res://scenes/tests/modular_environment_showcase_smoke_test.tscn
```

The tests cover the expanded nineteen-piece catalog, outdoor piece instantiation, remaster installation, module categories, legacy-presentation retirement, support-shell preservation, protected routes and zones, existing combat and puzzle contracts, save-state synchronization, checkpointing, and Church Trial handoff.

## Acceptance

The pass succeeds when the village feels like a broad outdoor route rather than an enlarged laboratory, while all existing authored gameplay remains reliable. The environment should alternate between landmarks, open travel, detail clusters, combat space, and quiet transitions instead of filling every meter with scenery.

## Known limitations

- The new outdoor pieces remain stylized primitive-based prototype assets rather than imported production meshes.
- The terrain underneath remains broad authored support boxes and ramps rather than sculpted landscape geometry.
- The church façade and towers have not yet received the modular production pass.
- Goblins and Gremlins remain stand-ins for location-specific enemies.
- Final foliage, decals, lightmaps, authored audio, cinematics, navigation meshes, and performance LODs are not represented.
