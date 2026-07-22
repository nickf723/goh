# Snowfall Concentration Weather v1

## Launch

Open and run:

`res://scenes/levels/prototypes/prototype_snow_weather_lab_v1.tscn`

## Core concentration contract

1. The player begins with 10 / 10 mana and Snowfall equipped.
2. Cast Snowfall with the normal Cast input.
3. Confirm the concentration HUD reports 45% concentration, 5 usable mana, and 5 reserved mana.
4. Confirm the current mana is clamped to 5 rather than continuously drained.
5. Switch to Ice Lance and cast repeatedly. Ice Lance should read FREE and should not reduce mana.
6. Cast Water Jet, Firebolt, or Lightning Spark. These spells should retain their normal costs.
7. Spend mana below 5 and wait. Mana should regenerate up to 5, then stop at the active ceiling.
8. Switch back to Snowfall and cast again. The weather should stop, Ice Lance should regain its ordinary cost, and mana should be able to regenerate toward 10 without instantly refilling.

## Environmental behavior

- Snowflakes should follow Grace within the laboratory and visibly drift rather than fall like Rain streaks.
- Both exposure probes should progress from DRY to FROSTING to FROZEN after repeated atmospheric pulses.
- The ground snow layer should accumulate gradually rather than appearing at full depth instantly.
- Walking across sufficiently accumulated snow should leave temporary footprints.
- The phase basin should progress from LIQUID WATER to FREEZING to FROZEN.
- Firebolt should melt basin ice and reduce ground accumulation when it hits those authored receivers.
- The exposed brazier should weaken and extinguish after repeated Snowfall pulses. Snow should take longer than Rain to suppress open flame.
- The environment should become colder, brighter, and foggier while Snowfall is active, then restore when dismissed.

## Reset

Press F8 while running from the editor.

The laboratory should:

- dismiss Snowfall without leaving concentration active,
- restore 10 / 10 mana,
- restore all spell costs,
- clear snow coverage and footprints,
- thaw the phase basin,
- reset both probes to DRY,
- relight the brazier,
- return Grace to the starting position.

## Known limitations

- Weather exposure uses the authored `weather_exposed` group. Roof and indoor occlusion are not simulated yet.
- Snow accumulation is a gameplay field rather than a deformable terrain simulation.
- Footprints are temporary procedural marks and do not yet encode creature identity or direction precisely.
- Slippery movement and load-bearing snow depth are deferred.
- Snowfall is currently a separate weather definition. Weather upgrades and mixed fronts remain undecided.
