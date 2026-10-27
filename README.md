# The Pale District — Narrative RPG Template

A Godot 4.7 starter project for a top-down, dialogue-driven detective RPG. The project is an original prototype inspired by broad genre conventions (isometric narrative RPGs, reactive dialogue, skill checks and environmental storytelling), not a recreation of any copyrighted game's characters, writing, art or locations.

## Included in this vertical slice

- Playable top-down character with WASD / arrow-key movement and mouse click-to-move.
- Clickable NPCs, interaction range and E-to-talk interaction.
- Branching conversations and contextual choices.
- Skill checks using 2d6 + skill rank + modifier, with success/failure branches.
- Character sheet with six example skills.
- Inventory and currency; a simple buy interaction.
- Journal with duplicate-safe clue entries and an evolving objective.
- JSON save/load to `user://pale_district_save.json` (F5 saves, F9 loads).
- Procedurally drawn placeholder street blockout and on-screen control hints.
- A single test scene configured as the project's main scene.

## Run

1. Install Godot 4.7 or a compatible Godot 4.x release.
2. Clone/download this repository.
3. Open `project.godot` in Godot.
4. Press F6 to run the current scene or F5 to run the project.

## Controls

| Input | Action |
| --- | --- |
| WASD / arrows | Move |
| Left-click ground | Walk to point |
| Right-click | Walk to point |
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
- `scenes/main.tscn` — test scene and player node.
- `scripts/game.gd` — world blockout, UI, interactions, dialogue, checks, journal, inventory and persistence.
- `scripts/player.gd` — movement controller and placeholder character drawing.
- `icon.svg` — project icon.

## Suggested next production steps

1. Replace the procedural blockout with authored TileMapLayer / Node2D scenes and collision geometry.
2. Extract dialogue, quest, inventory, character and save systems into reusable resources/autoloads.
3. Move dialogue content into JSON or custom Resources; add conditions, effects, skill gates and localization.
4. Add portrait illustrations, animated character sprites, sound, music, lighting and post-processing.
5. Add navigation/collision around buildings, accessible interaction prompts, controller support and automated tests.
6. Build a dialogue graph editor and a quest-state inspector for authoring content.

This is a feature-complete *starter vertical slice*, not a finished commercial game. Art and dialogue are placeholders intended to make the core loop testable immediately.
