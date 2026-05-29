# Multi-Slot Godot Template

Use this template when your game has manual saves, campaigns, or a slot-select screen. Each save uses a stable developer slot id such as `campaign-1` or `challenge`.

## Files

- `persistly_save_service.gd` wraps named slot save, load, list, and sync calls.
- `usage_example.gd` shows a slot-select style flow.

Use stable ids that do not change when the player renames a save.

