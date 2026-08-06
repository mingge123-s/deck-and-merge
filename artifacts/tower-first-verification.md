# U2 tower-priority verification

## Intent
When an enemy tower is inside a unit's full attack range (`stats.range`), `_step_battle` must prefer the tower over troop targets.

## Bug
`tower_reach` used `_engage_distance(unit)` (~`range*0.72` for projectiles), so units standing between engage and full range kept attacking troops.

## Fix
`tower_reach := maxf(float(unit.stats.get("range", 0.0)), TOWER_RANGE)`

## Logic cases (tower_dist vs reach → prefer tower?)

| case | range | engage | tower_dist | old_reach | new_reach | old_prefer_tower | new_prefer_tower |
|---|---:|---:|---:|---:|---:|---|---|
| melee clubber | 46.0 | 46.0 | 200.0 | 82.0 | 82.0 | False | False |
| ranged mid-band | 180.0 | 129.6 | 150.0 | 129.6 | 180.0 | False | True |
| ranged at engage edge | 180.0 | 129.6 | 129.6 | 129.6 | 180.0 | True | True |
| ranged just inside full range | 180.0 | 129.6 | 179.0 | 129.6 | 180.0 | False | True |
| ranged outside range | 180.0 | 129.6 | 200.0 | 129.6 | 180.0 | False | False |

## Critical assertion
- ranged range=180, tower_dist=150 (engage~129.6 … 180): old_prefer=False → new_prefer=True
- PASS: mid-band now prefers tower; melee unchanged (reach = max(range, TOWER_RANGE)).

## Headless
- Godot 4.7.1.stable headless `--quit-after 5`: SCRIPT ERROR count = 0 (see `artifacts/headless-boot.log`).
