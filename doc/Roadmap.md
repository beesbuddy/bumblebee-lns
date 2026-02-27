## Target

Baseline target: LoRaWAN L2 1.0.4 + RP002-1.0.5.
Optional second phase: LoRaWAN 1.1.

## Roadmap (Concrete)

Phase 0: Scope + Freeze (2-3 days)

Define target regions to support first (EU868, US915, etc.).

Freeze current behavior with regression tests for join/uplink/downlink.

Deliverable: test baseline + upgrade branch.

Files to start from: README.md, src/lorawan_mac.erl, src/lorawan_mac_region.erl.

Phase 1: Data Model Migration (4-6 days)

Add schema fields for modern key/counter model.

Keep backward compatibility path for existing nwkskey/appskey.

Add migration script for mnesia records.

Main files: include/lorawan_db.hrl, src/lorawan_db.erl, src/lorawan_admin_db_record.erl.

Phase 2: Core MAC/Join Refactor (1.0.4) (1-2 weeks)

Refactor join-accept and MIC logic to isolate “spec profile” behavior.

Normalize frame-counter handling and replay/reset checks per 1.0.4.

Preserve current 1.0.3 behavior behind compatibility switch until cutover.

Main files: src/lorawan_mac.erl, src/lorawan_handler.erl, src/lorawan_mac_commands.erl.

Phase 3: RP002-1.0.5 Regional Update (1 week)

Update datarate/channel-mask/channel-plan tables.

Validate US915/AU915 mask control and CFList behavior.

Add region-specific golden tests.

Main file: src/lorawan_mac_region.erl.

Phase 4: Conformance Test Pack (1 week)

Add executable test vectors for join, MIC, ADR, MAC command encode/decode.

Add integration tests for gateway uplink/downlink paths.

Main test files: test/loramote_tests.erl, test/load_tests.erl, test/test_forwarder.erl.

Phase 5: Cutover + Migration Release (3-4 days)

Deploy with dual-read/dual-write compatibility window.

Add config flag spec_profile = lorawan_1_0_4 defaulting to new behavior.

Publish migration/rollback docs.

Main docs: doc/Configuration.md, doc/Development.md.

Phase 6 (Optional): LoRaWAN 1.1 (2-4 weeks)

Implement root/session key split fully (NwkKey, FNwkSIntKey, SNwkSIntKey, NwkSEncKey, AppSKey).

Add 1.1 join/rejoin state machine and key derivation.

Add JS/roaming interoperability only if required by your deployments.

Acceptance Criteria

rebar3 compile, rebar3 release, and smoke boot pass on OTP 26.
Join/uplink/downlink tests pass for all enabled regions.
No regression for existing deployed 1.0.3 nodes during migration window.
Documented config switch and rollback path.
Suggested execution order now

I start with Phase 1 schema patch + migration scaffolding.
Then Phase 2 key/MIC refactor with compatibility switch.
Then Phase 3 region updates and tests.