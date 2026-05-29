# One-Save Godot Template

Use this template when your Godot game has one current save. It uses the default `autosave` slot through `save_data`, `load_data`, and `force_sync_data`.

## Files

- `persistly_save_service.gd` wraps the Persistly facade behind game-shaped methods.
- `usage_example.gd` shows where to call the service from your own game script.

Call `configure` once during startup, call `save_game` whenever local gameplay state changes, and call `sync_game` from deliberate lifecycle points such as checkpoint, pause, manual save, or app background.

