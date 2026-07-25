# Roadside Conversation, Quest, and Consequence v1

Run:

`scenes/levels/prototypes/prototype_roadside_conversation_lab_v1.tscn`

## Full adventure loop

1. Help Mara repair her cart through conversation.
2. Speak with her again and accept **The Cartographer's Missing Map**.
3. Follow the road south and discover the Gremlin camp.
4. Recover the map case through one of three systemic routes:
   - defeat the Gremlin sentry;
   - ring the abandoned bell and retrieve the case while it investigates;
   - use the Metal recovery point to pull the case from a distance.
5. Return to Mara.
6. Receive **Mara's Eastern Chart** as a persistent Key Item.
7. Speak with her again to confirm the completed-state dialogue.

Each solution records a distinct optional quest outcome.

## Controls

- Interact: conversations and field objectives
- Up / Down: select a dialogue response
- Confirm / Interact: choose or advance
- Cancel: leave dialogue or the journal
- Left Shoulder / H: conversation history
- Minus / J: Journey quest journal
- F8 in the editor: reset Mara, the quest, and the laboratory

## Quest substrate

Persistent quest records live in `GameState` and are included in saves. They support:

- inactive, active, completed, and failed states
- ordered stages and current objectives
- optional objective completion
- story-driven start, advancement, and resolution
- compact active/completed journal cards
- conversation entry rules based on previous outcomes
- inventory and Key Item rewards

Unavailable dialogue choices remain visible with their requirements.

## Smoke tests

`scenes/tests/roadside_conversation_smoke_test.tscn`

`scenes/tests/quest_system_smoke_test.tscn`
