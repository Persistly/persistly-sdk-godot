# Auth-Required Godot Template

Use this template when your game requires Firebase, Supabase, or Auth0 sign-in before cloud sync. Local saves still work before sign-in, but `force_sync_data`, `force_sync`, and due-sync calls return `auth_required` until a provider token is exchanged for a Persistly account session.

Provider tokens are sent only to the Auth Bridge session endpoint. Normal save/load/sync calls continue to use the returned Persistly `accountId` and `accountSessionToken`.

For Supabase, configure the provider in the Persistly dashboard with your Supabase project URL before exchanging access tokens from the game.

## Files

- `persistly_save_service.gd` wraps Firebase and Supabase Auth Bridge sign-in, linked provider listing, local save/load, explicit sync, and sign-out.
- `usage_example.gd` shows provider sign-in and the pre-sign-in local-save behavior.
