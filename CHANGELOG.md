# Changelog

## 1.0.0

- First stable Godot SDK release for Persistly cloud save sync.
- Adds `PersistlyGameSaves` as the recommended game-friendly facade for named slots, local-first saves, profile account data, profile sessions, due-slot sync, force sync, and explicit conflict states.
- Reconciles an existing remote slot when a local slot is missing its `characterSaveId`, preventing duplicate-slot errors after reinstall, cache loss, or local state drift.
- Keeps `PersistlyClient` raw profile, character, runtime config, and legacy save APIs available for advanced integrations.
- Adds dev/test live parity smoke tooling for real API validation without committing runtime keys.
- Pins `persistly-contract-v0.3.0`.

## 0.9.1

- Adds profile creation, profile session headers, profile-scoped character load/sync, runtime config, and local autosave draft helpers.
- Keeps raw save create/load/sync available as advanced APIs.
- Documents `profileSaveId`, `profileSessionToken`, character `saveId`, and integer save `version` semantics through the pinned contract bundle.

## 0.1.0

- Initial Godot SDK candidate for Persistly create, load, sync, local cache, typed sync status, and structured runtime errors.
- Includes Last Beacon playable sample for engine validation.
- Pins `persistly-contract-v0.2.0` for OpenAPI, examples, and runtime payload limits.
