# Marketplace Economy v1

## Laboratory

Run:

```text
scenes/levels/prototypes/prototype_marketplace_lab_v1.tscn
```

The marketplace demonstrates persistent currency, automatic coin collection, manual valuable collection, a reward chest, and a merchant supporting buying, selling, limited stock, and buyback.

## Playtest route

1. Walk through the four rotating coins. Crowns collect automatically.
2. Interact with the blue Starlit Gem on the right.
3. Open the treasure chest on the left for crowns, a gem, and Springwater.
4. Interact with Mara's stall.
5. Use Left and Right to change between Buy, Sell, and Buyback.
6. Buy an item and confirm both wallet and stock decrease.
7. Sell a Starlit Gem for 35 crowns.
8. Move to Buyback and recover the gem for the same 35 crowns.
9. Attempt a purchase without enough crowns.
10. Fill an item stack and verify a rejected purchase consumes neither stock nor currency.
11. Press F8 outside the shop to reset the laboratory.

## Economy rules

- Currency has a dedicated GameState wallet and is included in bed saves.
- Currency cannot become negative.
- Purchases check stock, funds, and inventory capacity before completing.
- Every purchase reduces limited merchant stock by one.
- Selling consumes exactly one item and grants its catalog sale value.
- Up to eight recent sales remain available through Buyback.
- Buyback charges the original sale value, avoiding an accidental-sale tax.
- Valuables such as the Starlit Gem exist primarily to be sold.
- Existing alchemy ingredients, potions, field tools, and quick items share the same economy catalog.

## Smoke test

```text
scenes/tests/marketplace_economy_smoke_test.tscn
```

The smoke test verifies purchasing, wallet deductions, inventory grants, limited stock, selling, and buyback.
