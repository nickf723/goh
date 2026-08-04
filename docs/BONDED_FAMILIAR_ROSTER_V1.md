# Bonded Familiar Roster v1

## Goal

Connect named world-animal relationships to the existing Summon Familiar spell without duplicating animals or replacing species familiar blueprints.

## Familiar slot sources

Grace has one familiar slot with two possible sources:

1. **Named bonded animal**
   - Comes from `AnimalBondStore`.
   - Must be bonded and treated as rescued.
   - Preserves animal name, species, personality, trust, familiarity, and persistent animal ID.
   - Takes priority over species blueprints while equipped.

2. **Species familiar blueprint**
   - Continues to use `SpeciesKnowledge` and `FamiliarDefinitionCatalog`.
   - Keeps role, temperament, opening command, and technique configuration.
   - Acts as the fallback when no named familiar is equipped.

## Runtime architecture

`BondedFamiliarRoster` is a root-level service started by the reusable player HUD bootstrap.

It owns:

- the equipped named-animal ID
- the previously equipped species blueprint ID
- a runtime `SummonDefinition` for the selected individual
- temporary summon-manager fallback overrides
- active manifestation state
- world-instance suppression and restoration

The service does not change the spell caster or the summon manager. While a named animal is equipped, it swaps only the summon manager's default definition. Clearing the named slot restores the manager's original definition.

## Persistence

Named familiar selection is saved to:

`user://goh_bonded_familiar_roster.json`

Animal identity and relationship data remain in:

`user://goh_named_animal_bonds.json`

Manifestation state is intentionally memory-only. A crash or fresh application launch can never leave the original world animal permanently hidden.

## Summon flow

1. A rescued, bonded animal appears in the full-menu Bonded Familiars section.
2. Equipping the individual records its persistent animal ID and remembers the current species blueprint as fallback.
3. The roster clears the active species selection for the current runtime and installs a named runtime definition.
4. Summon Familiar instantiates `bonded_animal_familiar.tscn` through the ordinary ability channel.
5. `SummonedBondedAnimalFamiliar` reads the equipped record before its procedural visual is built.
6. The summoned actor restores name, species, personality, relationship, and persistent ID.
7. The roster hides and disables any loaded world actor with the same persistent ID.
8. Dismissal restores the world actor and leaves the bond record unchanged.

## Commands

Named animal familiars expose the authoritative animal command set:

- Follow
- Stay Here
- Come Here
- Go There
- Dismiss Familiar

They use the same Cast-driven global ability context and active HUD support cluster as every other familiar.

## Regression

`res://scenes/tests/bonded_familiar_roster_smoke_test.tscn`

The regression verifies:

- a bonded Juniper record enters the roster
- identity, species, and trust tier round-trip
- named familiar selection saves to disk
- the reusable player receives the runtime summon definition
- Summon Familiar uses the actual ability channel
- Juniper manifests with the persistent record
- world Juniper is hidden and non-colliding while manifested
- Follow and Stay route through authoritative commands
- dismissal restores the world animal
- the bond survives dismissal
- manifestation state is not written to disk
- clearing the named slot restores Lumen's original definition
