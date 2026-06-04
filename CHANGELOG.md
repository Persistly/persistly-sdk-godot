# Changelog

## 1.0.0

- First stable Godot SDK release for Persistly cloud save sync.
- Adds `PersistlyGameSaves` as the recommended game-friendly facade for named slots, local-first saves, account data, account sessions, due-slot sync, force sync, and explicit conflict states.
- Reconciles an existing remote slot when local slot state is missing after reinstall, cache loss, or local state drift.
- Keeps `PersistlyClient` account, slot, and runtime config APIs available for advanced integrations without exposing legacy raw-save compatibility as the public release path.
- Adds dev/test live parity smoke tooling for real API validation without committing runtime keys.
- Pins `persistly-contract-v0.4.0`.

## 0.9.1

- Adds the pre-release account/slot runtime flow, runtime config, and local autosave draft helpers.
- Keeps advanced integrations on the account/slot runtime client while the release path moves away from raw-save compatibility.
- Documents pre-release account session and slot save semantics through the pinned contract bundle.

## 0.1.0

- Initial Godot SDK candidate for Persistly create, load, sync, local cache, typed sync status, and structured runtime errors.
- Includes Last Beacon playable sample for engine validation.
- Pins `persistly-contract-v0.2.0` for OpenAPI, examples, and runtime payload limits.
