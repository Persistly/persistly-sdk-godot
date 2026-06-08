# Auth-Required Godot Template

Use this template when your game requires Firebase sign-in before cloud sync. Local saves still work before sign-in, but `force_sync_data`, `force_sync`, and due-sync calls return `auth_required` until a Firebase ID token is exchanged for a Persistly account session.

Firebase tokens are sent only to the Auth Bridge session endpoint. Normal save/load/sync calls continue to use the returned Persistly `accountId` and `accountSessionToken`.

## Files

- `persistly_save_service.gd` wraps Firebase Auth Bridge sign-in, linked provider listing, local save/load, explicit sync, and sign-out.
- `usage_example.gd` shows Firebase sign-in and the pre-sign-in local-save behavior.
