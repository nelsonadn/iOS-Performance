# Architecture

## Components

`IOSPerformanceCore` is a Swift package independent of React Native and Capacitor. It owns named concurrent sessions, marks, sampled process/device metrics, JSON/CSV export, and Instruments signposts. React Native and Capacitor packages expose equivalent async APIs and forward every measurement operation to the core. They contain no metric sampling code.

The benchmark runner is a host-side macOS tool. Its `performance-projects.yml` may point to any local application checkout. A project entry declares framework, Xcode workspace/project, scheme, bundle identifier, build configuration, optional test target/destination, and result directory. The runner validates paths, invokes Xcode tooling, gathers SDK artifacts plus optional XCTest/xcresult/xctrace artifacts, normalizes available fields, and writes only under `iOS-Performance/results` by default. No credentials belong in this configuration.

The Performance Skill is invoked inside the target app repository. It discovers that repository's framework and source structure, checks the matching adapter, traces the requested flow, and makes the smallest explicit instrumentation edits while preserving app behavior. It must never assume a fixed checkout name or relative location of iOS-Performance.

## Measurement contract

Equivalent flows share scenario names and semantic event names such as `LOGIN`, `LOGIN_TAP`, `AUTH_API_START`, `AUTH_API_END`, `NAVIGATION_START`, `HOME_VISIBLE`, `HOME_DATA_START`, `HOME_DATA_END`, and `HOME_READY`. Applications may implement those boundaries differently; exported normalized result keys remain stable. Durations use a monotonic clock; wall-clock timestamps are metadata only.

## Sources and reliability

| Metric | Source | Reliability / limit |
|---|---|---|
| Elapsed time, marks, nested durations | Core monotonic clock | Reliable for in-process intervals after native core initialization |
| CPU current/average/peak | Core process CPU time deltas | Sampled estimate; brief spikes between samples can be missed |
| Memory | Core `phys_footprint` | Physical footprint estimate; point samples may miss short peaks |
| Frame cadence | Core `CADisplayLink` | Observed callback cadence and threshold estimate; not an authoritative hitch/drop count |
| Thermal/application state | Public `ProcessInfo` and UIKit | Thermal start/worst/end samples and application state at session start/end |
| Device/build context | Public platform APIs and app bundle metadata | Some device identity detail is intentionally omitted |
| Cold/warm launch | XCTest / xcodebuild | External measurement; required for time before SDK initialization |
| CPU/memory/hitches/storage | XCTest metrics where supported | External test-run measurements; availability depends on Xcode/OS/test configuration |
| Detailed CPU, allocations, Points of Interest | Instruments / xctrace | External trace; user/toolchain configuration required |

SDK metrics and XCTest/Instruments metrics are labeled separately. Missing values remain missing; no metric is synthesized from another source.

## Concurrency and sampling

The core serializes session mutations and sampling state. Independent sessions can overlap. A sampler runs only while at least one session is active and stops when the final session ends. Sampling interval is configurable. Signpost intervals identify sessions and custom marks are points of interest.

## Benchmark runner behavior

The config-driven runner selects an external project by key, verifies its repository and configured Xcode container, then builds the configured scheme. Scenario execution is supplied by an XCTest target/test name or an explicitly configured launch/instrumentation mechanism. It collects available result bundles and SDK exports, labels source/run/device/build metadata, and compares equivalent scenario keys. Project source is read-only to the runner. Comparisons should use the same physical iPhone, iOS release, backend, user data, network conditions, and Release configuration.

## Skill behavior

The Skill discovers the current repository type and installed adapter, traces the requested interaction from user action through API/navigation/render/data-ready boundaries, and edits only the relevant source files. Removal/show/API-only/render-only requests are supported. It does not change requests, navigation, business logic, or sensitive data handling.
