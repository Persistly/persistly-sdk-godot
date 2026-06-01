# Account + Slots Godot Template

Use this template when your game has sign-in, cross-device restore, or a backend that stores the Persistly account session for the player.

The token export path is explicit. Send `accountId` and `accountSessionToken` to your trusted backend over HTTPS, and never log the session token.

For games without their own authenticated backend yet, use short-lived transfer codes: create a code on the device that already has the account session, show it to the player, and consume it on an empty second device. Do not log transfer codes.

## Files

- `persistly_save_service.gd` wraps account attach/export, transfer-code attach, plus named slot save and sync.
- `usage_example.gd` shows first-device export, second-device attach, and anonymous transfer-code restore.
