# Persistly Godot SDK

This repository is the Godot runtime SDK for Persistly.

It pins contract bundle `persistly-contract-v0.2.0` under `contracts/` and keeps the public runtime surface intentionally small:

- `create_save(payload)`
- `load_save(save_id)`
- `sync_save(save_id, payload)`

The bundled contract and OpenAPI definition pin the runtime routes and payload envelopes. The client now implements a real blocking JSON transport with bearer auth while keeping the caller-facing API small and explicit.

The client is designed around small caller-provided configuration:

- `runtime_key` for bearer authentication
- optional `base_url` only for explicit validation infrastructure

There is no `player_ref` lookup helper in this scaffold. The caller is expected to resolve identity outside the SDK and pass the runtime credentials directly.

## Install

Copy both directories into your Godot project:

```text
addons/persistly/
contracts/
```

The addon reads the pinned contract bundle from `res://contracts/persistly-contract-v0.2.0`, so copying only the addon without `contracts/` is incomplete.

When the public repository is connected, use:

```text
https://github.com/Persistly/persistly-sdk-godot
```

## Quickstart

1. Use a `ps_test_...` key for non-production traffic.
2. Create a save once and persist the returned `saveId` locally.
3. Load and sync only by `saveId`.
4. Treat conflict responses as explicit product behavior, not as generic transport failures.

Runtime behavior:

- HTTPS or HTTP JSON requests via `HTTPClient`
- `Authorization: Bearer <runtime_key>`
- request paths and payload envelopes are defined by the bundled contract/OpenAPI and treated as fixed
- accepted and conflict sync responses both preserve the canonical `save` payload
- a small in-memory cache stores canonical saves by `saveId`
- `sync_save` can infer `baseVersion` from the cache when the caller omits it

Validation:

- `scripts/validate_contract.gd` checks the pinned contract bundle manifest and file integrity
- `scripts/validate_client.gd` drives the client against fixture responses to verify create, load, sync, accepted/conflict sync semantics, error mapping, and cache behavior without needing a live API

The SDK targets `https://api.persistly.app` by default. Keep custom or fixture endpoints only in clearly labeled validation flows.

## Playable Proof

This repo now includes `examples/last_beacon/`, a small endless idle demo that uses the SDK directly and stores its local profile under `user://`.

The playable example exists to prove:

- create/load/sync flows inside a real Godot project
- explicit `saveId`-based resume behavior
- local persistence for runtime config plus save identity
- a minimal but genuine game loop instead of a one-shot request example

## Release Checklist

- validate the pinned contract bundle
- run the client validation scripts
- launch `Last Beacon` and verify create, load, sync, and conflict handling against a real runtime key
- keep example defaults aligned with `https://api.persistly.app`
