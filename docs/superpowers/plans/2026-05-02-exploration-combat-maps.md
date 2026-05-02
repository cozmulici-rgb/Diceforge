# Exploration Combat Map Plan

## Goal

Expand the exploration route map so combat nodes read like a planned campaign of arenas instead of placeholder encounters.

## Tutorial

- `tutorial_hall`: `MAP-TUT-01` "Shiver Hall"
  Cold-entry lane that teaches the first hostile commit.

## Floor 01: Fractured Approach

- `floor_01_fight`: `MAP-F01-01` "Fracture Bridge"
  Narrow crystal bridge used as the first pressure-check fight.
- `floor_01_gallery`: `MAP-F01-02` "Needle Gallery"
  Long sightlines and shard cover that reward controlled sequencing.
- `floor_01_vault`: `MAP-F01-03` "Vault Stair"
  Vertical choke arena reached from the safer broker branch.
- `floor_01_choir`: `MAP-F01-04` "Choir of Ash Glass"
  Convergence map where both routes rejoin before the boss.
- `floor_01_boss`: `MAP-F01-BOSS` "Overseer Dais"
  First boss arena with a ceremonial center lane.

## Floor 02: Silent Apex

- `floor_02_fight`: `MAP-F02-01` "Guardwalk"
  Direct approach arena with little cover and fast engagement.
- `floor_02_causeway`: `MAP-F02-02` "Mirror Causeway"
  Shrine branch that folds back into the critical path.
- `floor_02_crucible`: `MAP-F02-03` "Crown Crucible"
  Final standard fight before the ascent lock.
- `floor_02_boss`: `MAP-F02-BOSS` "Warden Core"
  End-run arena built around a single exposed heartline.

## Placement Notes

- Keep named combat maps attached to room nodes as metadata, not a parallel system.
- Show the selected node's combat map ID, theme, and summary in the exploration sidebar.
- Count charted combat maps in the map header so each floor feels authored.
