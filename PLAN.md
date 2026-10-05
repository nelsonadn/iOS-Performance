# Implementation Plan

## Status

| Phase | Scope | Status |
|---|---|---|
| 0 | Reference analysis and architecture | Complete |
| 1–2 | Shared Swift measurement core and public API | Implemented; host tests and iOS cross-build pass |
| 3 | React Native adapter | Implemented; host-app integration not validated |
| 4 | Capacitor adapter | Implemented; host-app integration not validated |
| 5 | External-repository Performance Skill | Implemented with framework discovery, arbitrary flow tracing, service/HTML request guidance, and privacy review; not installed into a user-level Codex skills directory |
| 6–7 | Configurable external-project runner, exports, comparison | Implemented for external checkouts, SDK JSON attachments, XCTest metrics, normalization and comparison; xctrace automation remains |
| 8–9 | Independent examples and documentation | Independent framework examples and agent/console instructions implemented; full host project scaffolding remains |
| 10–11 | Tests and overhead methodology | Core contract/privacy tests and overhead methodology implemented; adapter coverage and measured overhead remain |
| 12 | Developer scripts and packaging | Core runner scripts implemented; npm release packaging remains |

## Phase 0 findings

The two reference projects are independent upstream repositories and remain read-only. `react-native-performance` provides User Timing style marks/metrics, monotonic timestamp handling, React Native startup marks, and a legacy native module with a New Architecture TurboModule path. `react-native-performance-toolkit` demonstrates iOS sampling from `rusage`, `task_vm_info.phys_footprint`, and `CADisplayLink`; its sampling is lazy but continues after first access. Their framework-specific bridge code is not appropriate for the common engine.

The target repository must be installable from unrelated application repositories. The runner therefore owns a project registry (`performance-projects.yml`) with paths resolved relative to that configuration file (absolute paths are also accepted). Adapter packages are installed by each target app; runner operations may read/build/launch target repositories but must never edit their source. Flow instrumentation is a separate explicit developer action performed by the reusable Skill in the current target repository.

## Implementation order

1. Create the Swift package and implement the framework-independent measurement model, monotonic timing, signposts, sampling, and exports.
2. Add thin framework adapters that call the same native API.
3. Add the reusable Skill, runnable in an arbitrary current app repository.
4. Add a config-driven runner, normalized result storage, and cross-repository comparison.
5. Add examples and complete usage/limitations documentation.
6. Add validation coverage and local developer scripts; report host-specific limitations explicitly.

At each phase, build and run the applicable checks before proceeding. The system will not claim acceptance for functionality that cannot be built or exercised in the available host environment.

## Current validation record

- `swift test` in `packages/ios-core`: core session, export, sampling, and event-name privacy coverage.
- `swift build --destination /private/tmp/ios-perf-destination.json`: iOS 15 arm64 core cross-build passed, including UIKit and CADisplayLink code.
- Ruby syntax checks passed for the benchmark and comparison scripts; Bash syntax checks passed for all runner entry scripts.
- The two reference repositories were read-only during this work.
- React Native / Capacitor host builds and TypeScript declaration consumption are not yet validated because no consuming app repositories are configured in `performance-projects.yml`.
