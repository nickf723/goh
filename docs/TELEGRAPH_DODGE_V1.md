# Enemy Telegraphs and Perfect Dodges v1

Run:

```text
scenes/levels/prototypes/prototype_telegraph_dodge_lab_v1.tscn
```

## Combat contract

Enemy attacks progress through authored phases:

```text
Idle → Windup → Active → Recovery
```

The enemy locks its heading when windup begins. Floor geometry therefore communicates the real strike area instead of following Grace until impact.

- **Wide Sweep:** circular, medium timing, interruptible.
- **Overhead Crush:** forward impact zone, slow and committed.
- **Driving Thrust:** narrow lane, fast and interruptible.
- **Delayed Ruin:** large circular blast, heavily delayed and committed.

Orange windups can be interrupted. Deep-red committed windups have super armor. Recovery and blue counter windows are always punishable.

## Perfect dodge

A dodge begins with a short perfect window. If an active enemy hit intersects Grace during that window:

- the attack deals no damage;
- stamina is restored;
- brief hit-stop emphasizes the evade;
- the attacker turns blue;
- a guaranteed counter window opens.

Dodging later during ordinary invulnerability avoids damage without opening the special counter opportunity.

## Controls

- Move: WASD / left stick
- Dodge: C / controller bottom face
- Light attack: J / left mouse / controller left face
- Heavy attack: K / mouse 4 / controller right face
- Force attack family: number keys 1–4
- Reset: F8

The compact HUD shows attack phase, remaining phase time, commitment, last result, counter time, perfect-window time, and stamina.

## Automated contract scene

```text
scenes/tests/telegraph_dodge_smoke_test.tscn
```

The test verifies all four profiles, perfect-dodge rewards, counter interruption, and committed super armor.
