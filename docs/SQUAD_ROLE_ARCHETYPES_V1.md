# Squad Role Archetypes v1

## Purpose

Squad roles give tactical actors complementary encounter jobs without replacing their existing personalities, species behavior, action resources, chemistry logic, or movement controllers.

```text
Personality = how the actor behaves
Squad role  = what the actor is responsible for
Actions     = what the actor can actually perform
```

A cautious Primer and a bold Primer share a setup responsibility but approach it with different commitment, movement, threat response, and hazard tolerance.

## Authored roles

Role profiles are `SquadRoleProfile` resources under:

```text
res://data/ai/squad_roles/
```

### Generalist

Fallback role for action libraries without a credible specialty. Generalists receive only a small broad preference and have no squad cap.

### Primer

Prefers:

- setup capabilities
- status and terrain control
- reaction setup opportunities
- Water, Ice, Poison, and Sound-style setup tags

Automatic assignment requires at least one setup-capable action.

### Payoff Specialist

Prefers:

- direct damage
- reaction payoff opportunities
- Lightning, Fire, heavy impact, force, and shatter-style tags

Automatic assignment requires a payoff capability or a detonator-like tag. Ruvia is explicitly authored as the `grace_party` Payoff Specialist.

### Protector

Prefers:

- defense and support actions
- guards, shields, healing, and blocking
- cover responses
- emergency defense

Automatic assignment requires a defensive action, capability, or tag.

### Disruptor

Prefers:

- control and setup
- stun, slow, force, push, pull, silence, Sound, and traps
- reaction setup and cover opportunities

Automatic assignment requires control capability or an authored disruption tag.

### Skirmisher

Prefers:

- ranged and projectile pressure
- movement, dodge, retreat, and repositioning
- covering allied withdrawals
- open engagement lanes

Automatic assignment requires movement capability or a mobile/ranged tag.

## Assignment ordering

Automatic assignment uses the actor's real `TacticalActionCandidate` records.

```text
qualified role fit
- duplicate-role penalty
- role cap violation
= assignment score
```

Roles with more specific semantic requirements receive stronger assignment priority than broad roles. A Lightning projectile may qualify as both Payoff Specialist and Skirmisher, but the elemental payoff role wins when available.

Explicit encounter authoring always wins. Setting `tactical_squad_role_id` to a concrete role bypasses automatic eligibility and squad caps. This supports bosses, scripted encounters, and deliberately redundant formations.

## Runtime scoring

Role scoring occurs after ordinary tactical validation:

```text
base action score
-> chemistry and target-state evaluation
-> hazard and survival checks
-> squad claims, protected states, lanes, and cover
-> squad role alignment
```

A role cannot make an invalid action valid. It cannot override protected setup states, severe hazard vetoes, resource availability, or emergency survival logic.

Role alignment contributes inspectable reasons and a `squad_role_alignment` opportunity to the tactical trace. The flight recorder displays the role name and the numerical role contribution for every candidate.

## Squad lifetime

Enemy roles persist for the actor's encounter lifetime. Individual setup, payoff, lane, and emergency reservations still expire or release after each action.

Role assignments contain IDs, labels, and scores only. They do not retain actor references. Assignments are released when the actor leaves the scene.

## Authoring a new role

1. Create a `SquadRoleProfile` resource.
2. Define assignment requirements so unqualified actors cannot receive it automatically.
3. Define preferred capabilities, tags, opportunity types, action kinds, and movement modes.
4. Define discouraged traits sparingly.
5. Set a per-squad cap and duplicate penalty.
6. Add the resource to `SquadRoleCatalog`.
7. Extend the archetype smoke test with both assignment and decision scenarios.

Avoid species names, scene paths, or action IDs in role profiles. Roles should describe tactical jobs that any compatible actor can perform.

## Regression

Run:

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/squad_role_archetype_smoke_test.tscn
```

Expected:

```text
SQUAD_ROLE_ARCHETYPE_SMOKE_TEST: PASS
```

The regression verifies:

1. catalog validity and aliases
2. assignment eligibility
3. complementary automatic role composition
4. per-role caps
5. explicit role overrides
6. release behavior
7. Primer, Payoff, Protector, Disruptor, and Skirmisher decision changes
8. role-alignment trace output
9. enemy runtime integration
10. Ruvia's authored Payoff Specialist role
