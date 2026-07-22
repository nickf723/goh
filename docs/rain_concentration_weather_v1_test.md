# Rain Concentration Weather v1 Playtest

## Scene

`res://scenes/levels/prototypes/prototype_rain_weather_lab_v1.tscn`

## Purpose

Validate the first sustained concentration spell and weather state:

- Rain reserves 40% of Grace's maximum mana instead of charging a fixed cost.
- With 10 maximum mana, the usable ceiling becomes 6.
- Current mana is clamped to the usable ceiling when Rain begins.
- Mana may be spent and regenerated only up to 6 while Rain remains active.
- Water abilities become free during Rain.
- Fire, Ice, and Lightning keep their normal costs.
- Rain acts as an infinite environmental Water source.
- Authored outdoor targets receive recurring Water exposure.
- Rain can be dismissed by casting Rain again.
- Ending Rain releases the full mana ceiling without instantly refilling it.

## Controls

- Move and aim with the normal player controls.
- Cast the equipped spell with `CAST` / right trigger.
- Use the Focus spell selector to switch among Rain, Water Jet, Firebolt, Lightning Spark, and Ice Lance.
- Press `F8` in the editor to reset the laboratory.

## Playtest route

1. Start the room and confirm the readout reports 10 / 10 mana, Rain dormant, and Water Jet costing 1 mana.
2. Cast Rain.
3. Confirm rain streaks appear, the atmosphere darkens, and the concentration HUD appears.
4. Confirm mana becomes 6 / 6 usable with 4 reserved.
5. Confirm the two exposure probes change from DRY to WET.
6. Confirm the rain-exposed brazier is extinguished after repeated exposure.
7. Confirm the collector basin fills visually and reports an infinite atmospheric Water source.
8. Switch to Water Jet and cast repeatedly. Confirm its listed cost is FREE and current mana does not fall.
9. Switch to Firebolt, Ice Lance, or Lightning Spark and cast. Confirm those spells still spend mana.
10. Wait and confirm passive regeneration stops at 6 while Rain is active.
11. Switch back to Rain and cast again.
12. Confirm rain stops, the atmospheric presentation clears, Water Jet returns to its normal cost, and the concentration HUD disappears.
13. Spend mana below 10, dismiss Rain if needed, and confirm regeneration can now continue toward the full maximum of 10.
14. Press F8 and confirm Rain ends, probes return to DRY, the player resets, the basin empties, and the brazier reignites.

## Controller feel review

Judge these points rather than final art quality:

- Does Rain feel like entering a committed build state rather than paying a normal spell cost?
- Is the 40% reservation immediately understandable from the HUD and arena readout?
- Does casting Water freely feel powerful enough to justify the reduced general-purpose mana pool?
- Is casting Rain again a natural dismissal input?
- Is the transition into and out of weather responsive without feeling like a disposable toggle?

## Known limitations

- Rain exposure is currently opt-in through the `weather_exposed` group. Roofs and interior occlusion are not simulated yet.
- The rain renderer uses procedural prototype streaks around Grace rather than a final particle or screen-space weather solution.
- Only Rain is implemented. Thunderstorm can later become either a separate WeatherDefinition or a Rain progression variant without changing the concentration foundation.
- Flight and other non-weather concentration abilities are intentionally deferred, but they can reuse ConcentrationEffectDefinition and ConcentrationManager.
- The prototype mutates equipped ability costs while concentration is active, then restores them. A future cost-query layer may replace this when the broader spell economy is finalized.
