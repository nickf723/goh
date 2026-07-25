# Roadside Conversation and Choice v1

Run:

`scenes/levels/prototypes/prototype_roadside_conversation_lab_v1.tscn`

## Controls

- Interact: begin or advance dialogue
- Up / Down: select a response
- Confirm / Interact: choose the highlighted response
- Cancel: leave the conversation
- Left Shoulder / H: toggle conversation history
- F8 in the editor: reset Mara's test flags and reload the lab

The conversation temporarily pauses ordinary player simulation, so movement, attacks, spells, enemies, and resource systems cannot consume the same input.

## Reusable contract

`ConversationNPC` consumes a dictionary graph containing an entry node and named dialogue nodes. Nodes may contain text, a next node, or choices.

Choices currently support:

- item requirements and consumption
- stat requirements
- required or blocking story flags
- story-flag writes
- objective updates
- inventory grants
- relationship changes
- persistent repeat-entry dialogue
- conversation history

Unavailable choices remain visible with their requirement, making the reason legible rather than silently removing the option.

## Playtest route

1. Approach Mara and use Interact.
2. Ask what happened, then return to the first response set.
3. Move through responses with both keyboard and controller.
4. Confirm the Charisma response is visibly gated if Grace has less than 2 Charisma.
5. Help with a Healing Flask or Metal affinity.
6. Confirm the relevant resource, trust value, and objective change.
7. Use Left Shoulder or H to review dialogue history.
8. Finish the conversation and speak with Mara again.
9. Confirm she remembers Grace and presents the follow-up branch.
10. Cancel from a conversation and confirm ordinary movement resumes.

Smoke test:

`scenes/tests/roadside_conversation_smoke_test.tscn`
