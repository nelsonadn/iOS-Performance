# Reference Repository Analysis

The reference repositories were inspected in place and were not modified.

## `react-native-performance`

The project implements a User Timing style model: named marks and metrics with timestamps, entry observers, and native startup timing. Its iOS bridge reads React Native performance logger tags, observes content appearance and JavaScript bundle load, and supports both the legacy bridge and a TurboModule code path. The native timestamp helper explicitly aligns with React Native's `CACurrentMediaTime()` clock so native and JavaScript timestamps can be compared. This clock alignment is a useful lesson; bridge-specific startup internals are not portable to Capacitor.

## `react-native-performance-toolkit`

The toolkit demonstrates process CPU sampling via deltas from `getrusage(RUSAGE_SELF)`, physical footprint via `task_vm_info`, and UI cadence observation via `CADisplayLink`. It exposes buffers and subscriptions to React Native through Nitro. The CPU value needs at least two samples. Its lazy startup is useful, but persistent tracking after first access does not meet this project's requirement to sample only while sessions are active. `CADisplayLink` callback cadence is an observed cadence estimate, not an authoritative count of dropped frames.

## Reuse decisions

No source code is copied in Phase 0. Adopt the concepts of monotonic timestamps, named timeline events, process CPU deltas, physical footprint, and display-link observation. If implementation later copies source, preserve the applicable MIT notice in the relevant files and `THIRD_PARTY_NOTICES.md`.

Do not reuse React Native bridge classes, Nitro buffers, JS-thread FPS estimators, or assumptions about React Native startup internals. Both adapters should only translate arguments/results and delegate to one Swift engine.

## Repository independence

The application repositories are separate checkouts. The packages under `packages/react-native` and `packages/capacitor` are installed independently into their matching applications. The runner reads a YAML registry in iOS-Performance and resolves each configured path relative to the registry file or as an absolute path. It validates and builds external projects, stores result artifacts in this repository, and never patches application source. The Skill operates from the current application repository and discovers framework, adapter, flow, and project-specific paths there; it does not assume a monorepo or fixed app names.

## Licensing

The React Native Performance repository is MIT licensed (Joel Arvidsson, 2019–present). The toolkit repository is MIT licensed; implementation attribution should be retained if code is reused. The common core will be independently implemented against public Apple APIs unless a later file explicitly documents copied material.
