# The Pale District — 3D Narrative RPG Template

A Godot 4.7 starter project for a 3D isometric, dialogue-driven detective RPG. This is an original prototype using broad genre conventions rather than copyrighted characters, writing, art or locations.

## Included in this vertical slice

- A 3D isometric waterfront blockout with water, road, pavement, kiosk and placeholder buildings.
- A perspective-free orthographic camera that follows the player from an elevated angle.
- 3D CharacterBody movement with WASD / arrow keys and click-to-move across the ground.
- Three 3D NPCs with name labels, hover highlighting and click-to-approach / talk interaction.
- Branching conversations and contextual choices.
- Skill checks using 2d6 + skill rank + modifier, with success/failure branches.
- Character sheet with six example skills.
- Inventory and currency; a simple buy interaction.
- Journal with duplicate-safe clue entries and an evolving objective.
- JSON save/load to `user://pale_district_save.json` (F5 saves, F9 loads).
- Overcast-style directional lighting, shadows and a muted palette.
- A headless GitHub Actions smoke test for import and scene startup.

## Run

1. Install Godot 4.7 or a compatible Godot 4.x release.
2. Download/clone the `feature/narrative-rpg-template` branch.
3. Open `project.godot` in Godot.
4. Press F5 to run the project.

## Controls

| Input | Action |
| --- | --- |
| WASD / arrows | Move in world space |
| Left-click ground | Walk to point |
| Left-click NPC | Approach or talk |
| E | Talk to nearest NPC |
| J | Journal |
| I | Inventory |
| C | Character / skills |
| F5 | Save |
| F9 | Load |
| Esc | Close panel |

## Folder layout

- `project.godot` — project settings and input map.
- `scenes/main.tscn` — 3D test scene and player.
- `scripts/game.gd` — 3D blockout, camera, NPCs, UI, dialogue, checks, journal, inventory and persistence.
- `scripts/player.gd` — 3D CharacterBody movement and click-to-move.
- `icon.svg` — project icon.
- `.github/workflows/godot-smoke-test.yml` — headless import and scene-start check.

## Production roadmap

1. Replace placeholder geometry with authored modular 3D models, PBR materials, decals and props.
2. Add NavigationRegion3D / NavigationAgent3D, proper collision layout, slopes, stairs and obstacle-aware click-to-move.
3. Extract dialogue, quest, inventory, character and save systems into reusable resources/autoloads.
4. Add a thought cabinet, relationship state, reactive checks, conditional dialogue graph and quest-state inspector.
5. Add portrait illustrations, facial/body animation, voice, ambience, music, weather and post-processing.
6. Add dialogue graph editor, controller support, accessibility options and automated gameplay tests.

This is a playable *starter vertical slice*, not a finished commercial game. The scene currently uses procedural placeholder geometry and simplified movement; visual and interaction polish remain on the roadmap.
