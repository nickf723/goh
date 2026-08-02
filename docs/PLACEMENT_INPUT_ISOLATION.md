# Placement Input Isolation

Recorded Object and Engineering Build managers no longer listen to controller buttons while placement is dormant.

Normal gameplay owns the combat, jump, dodge, and shoulder inputs. Placement controls become active only after a menu or an already-recorded/saved station deliberately begins placement.

## Controller placement state

While placement is active:

- A confirms placement
- B cancels placement
- L/R cycle available blueprints or builds

After placement is confirmed or cancelled, controller ownership returns to ordinary gameplay on the next frame.

## Laboratory entry

- Recorded Object station: first interaction records the blueprint; interacting again begins placement.
- Engineering Build station: first successful interaction saves the construction; interacting again begins placement.
- Items → Objects still begins production object placement through the two-confirm menu flow.

## Regression

`res://scenes/tests/placement_input_isolation_smoke_test.tscn`

Expected:

`PLACEMENT_INPUT_ISOLATION_SMOKE_TEST: PASS`
