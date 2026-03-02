# Migration Plan: LoRaWAN 1.0.4 and 1.1.0

## Goal
Upgrade the network server behavior from the current 1.0.3-style implementation to:
- LoRaWAN 1.0.4 compatibility mode
- LoRaWAN 1.1.0 compatibility mode

The plan is ordered by implementation risk and dependency chain.

## Current Gaps (from code audit)
- No per-device/profile LoRaWAN MAC version switch.
- No Rejoin-Request handling.
- Join/key derivation is 1.0.x only.
- `OptNeg` in Join-Accept is fixed to `0`.
- Uplink/downlink MIC and FRMPayload cryptography mostly use a single `NwkSKey` path.
- No split 1.1 downlink counters (`NFCntDown`, `AFCntDown`) in node state.
- 1.1 MAC commands are missing (`Rekey`, `ADRParamSetup`, `ForceRejoin`, `RejoinParamSetup`).
- DevNonce replay handling is not strong enough for modern deployments.

## Baseline Regression Tests (added)
These tests lock current 1.0.3-era behavior so refactoring for 1.0.4/1.1.0 can be done safely.

- `src/lorawan_mac.erl`
  - crypto vector compatibility (`cipher/5`, `b0/4`)
  - frame counter gap/increment semantics
  - CFList encoding behavior
- `src/lorawan_mac_commands.erl`
  - uplink FOpts parsing vector
  - downlink FOpts encoding vector
  - existing DeviceTime reference test

Run locally:
- `rebar3 eunit --module=lorawan_mac`
- `rebar3 eunit --module=lorawan_mac_commands`

---

## Phase 0: Safety Rails Before Protocol Changes
- [ ] Add feature flags:
  - [ ] `lorawan_1_0_4_enabled` (default `false`)
  - [ ] `lorawan_1_1_0_enabled` (default `false`)
  - [ ] `lorawan_1_1_rejoin_enabled` (default `false`)
- [ ] Add protocol metrics:
  - [ ] joins by version
  - [ ] MIC failures by frame type
  - [ ] rejected nonces/counters
- [ ] Add structured logs with version and key mode tags.

Acceptance:
- Flags can disable all new behavior without code rollback.

---

## Phase 1: Data Model and Backward-Compatible Schema Migration
High risk: persistent data changes.

### 1.1 Device/Profile metadata
- [ ] Add `mac_version` (or equivalent) to profile/device.
  - Suggested values: `<<"1.0.3">>`, `<<"1.0.4">>`, `<<"1.1.0">>`.
- [ ] Keep default at legacy behavior for existing records.

### 1.2 Node/session state for 1.1
- [ ] Add separate counters to node record:
  - [ ] `n_fcntdown`
  - [ ] `a_fcntdown`
- [ ] Keep `fcntdown` for backward compatibility until full cutover.
- [ ] Add join/rejoin state:
  - [ ] last `join_nonce` used/seen
  - [ ] `rjcount0` and `rjcount1` tracking as needed
  - [ ] stronger nonce history policy

### 1.3 Key state
- [ ] Keep existing fields for 1.0.x (`nwkskey`, `appskey`).
- [ ] Add/ensure 1.1 session key material storage:
  - [ ] `f_nwk_s_int_key`
  - [ ] `s_nwk_s_int_key`
  - [ ] `nwk_s_enc_key`
  - [ ] `app_s_key`
- [ ] Define storage for root keys used in 1.1 flow (`NwkKey`, `AppKey`) and ownership rules.

### 1.4 Migration routine
- [ ] Implement table transform in `lorawan_db` with defaults.
- [ ] On migration, map legacy values:
  - [ ] `fcntdown -> n_fcntdown` (initial bridge mode)
  - [ ] single Nwk key -> all 1.1 network key slots (temporary compatibility)

Acceptance:
- Existing DB boots cleanly.
- Existing 1.0.x devices continue to work unchanged.

---

## Phase 2: Version Selection and Routing in MAC Processing
Medium-high risk: message handling changes.

- [ ] In ingest path, resolve effective MAC version per device/node.
- [ ] Route all cryptographic operations via version-specific handlers:
  - [ ] join-request verification
  - [ ] join-accept generation
  - [ ] data MIC verification
  - [ ] payload encryption/decryption
- [ ] Add explicit branch points in `lorawan_mac.erl` rather than implicit key reuse.

Acceptance:
- For legacy profiles, behavior is byte-for-byte identical to current implementation.

---

## Phase 3: LoRaWAN 1.0.4 Compliance Pass
Lower risk than 1.1, good intermediate milestone.

- [ ] Add strict 1.0.4 replay/counter validation rules.
- [ ] Improve DevNonce policy and retention window.
- [ ] Add conformance tests for 1.0.4 join/data edge cases.
- [ ] Validate all currently supported MAC commands against 1.0.4 expectations.

Acceptance:
- 1.0.4 test suite passes.
- No regression for existing 1.0.x production devices.

---

## Phase 4: LoRaWAN 1.1 Join and Session Key Derivation
High risk: cryptography + interoperability.

### 4.1 Join handling
- [ ] Parse and verify 1.1 join specifics.
- [ ] Set Join-Accept `OptNeg` correctly for 1.1 mode.
- [ ] Implement 1.1-compliant Join-Accept MIC/encryption logic.

### 4.2 Session derivation
- [ ] Implement 1.1 key derivation tree using correct root key and context.
- [ ] Stop assigning one key to all network-key slots in 1.1 mode.

### 4.3 Counter semantics
- [ ] Use split downlink counters (`NFCntDown`, `AFCntDown`) based on payload class/FPort.
- [ ] Keep legacy single-counter path only for 1.0.x mode.

Acceptance:
- Known-good 1.1 vectors pass for join and first uplink/downlink cycle.

---

## Phase 5: LoRaWAN 1.1 Data Plane MIC/Crypto
High risk: silent data rejection if wrong.

- [ ] Use `FNwkSIntKey` for uplink MIC verification where required.
- [ ] Use correct 1.1 key/counter selection for downlink MIC generation.
- [ ] Use `NwkSEncKey` for network payload encryption semantics where required.
- [ ] Keep application payload crypto on `AppSKey`.

Acceptance:
- Interop test with at least 2 external 1.1 device stacks succeeds.

---

## Phase 6: Rejoin-Request Support
Medium-high risk.

- [ ] Add parser for Rejoin frame type(s).
- [ ] Validate rejoin counters and anti-replay windows.
- [ ] Implement rejoin-triggered session refresh and key rotation behavior.
- [ ] Add policy controls for rejoin acceptance.

Acceptance:
- Rejoin vectors pass, including reject cases.

---

## Phase 7: MAC Commands for 1.1
Medium risk.

- [ ] Extend `lorawan_mac_commands` parser/encoder:
  - [ ] `RekeyInd` / `RekeyConf`
  - [ ] `ADRParamSetupReq` / `ADRParamSetupAns`
  - [ ] `ForceRejoinReq`
  - [ ] `RejoinParamSetupReq` / `RejoinParamSetupAns`
- [ ] Add state-machine hooks for command side effects.

Acceptance:
- Command round-trip tests and downlink scheduler behavior pass.

---

## Phase 8: Interoperability and Conformance Testing
- [ ] Add deterministic test vectors for:
  - [ ] join MIC verification
  - [ ] join-accept MIC/encryption
  - [ ] uplink/downlink MIC
  - [ ] FRMPayload encrypt/decrypt
  - [ ] counter rollover and replay
- [ ] Add integration tests with real gateway path (`router-info` + uplink/downlink loop).
- [ ] Build compatibility matrix:
  - [ ] 1.0.3 devices
  - [ ] 1.0.4 devices
  - [ ] 1.1.0 devices

Acceptance:
- CI has protocol-level pass/fail gate for each version mode.

---

## Phase 9: Rollout Strategy
- [ ] Deploy with 1.1 flags disabled.
- [ ] Enable 1.0.4 mode for a pilot profile/group.
- [ ] Enable 1.1 join only, then 1.1 full data plane.
- [ ] Monitor:
  - [ ] join success/failure ratio
  - [ ] MIC failure spikes
  - [ ] duplicate/replay rejects
- [ ] Keep immediate rollback via feature flags.

Acceptance:
- Stable production metrics for one full device duty-cycle window.

---

## Suggested Work Breakdown (Sprints)
1. Sprint 1:
   - Phase 0 + Phase 1
   - Non-crypto schema and migration tests
2. Sprint 2:
   - Phase 2 + Phase 3
   - 1.0.4 compliance milestone
3. Sprint 3:
   - Phase 4 + Phase 5
   - 1.1 join + data plane crypto
4. Sprint 4:
   - Phase 6 + Phase 7 + Phase 8
   - Rejoin + 1.1 MAC commands + full conformance
5. Sprint 5:
   - Phase 9
   - Gradual production rollout

---

## Definition of Done
- [ ] 1.0.4 profile passes conformance and field tests.
- [ ] 1.1 profile passes conformance and field tests.
- [ ] Legacy 1.0.x fleet has no regression in join/data reliability.
- [ ] Rollback is configuration-only (no emergency DB rollback needed).
