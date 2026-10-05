# iOS Performance

An iOS measurement SDK, thin React Native and Capacitor adapters, reusable instrumentation Skill, and benchmark runner for comparing flows in independent repositories. Android is not implemented.

## Repository layout and model

```text
~/Projects/iOS-Performance/       SDK, runner, normalized results
~/Projects/BankApp-ReactNative/   independent React Native app
~/Projects/BankApp-Capacitor/     independent Capacitor + Ionic/Angular app
```

Each app installs only its matching adapter. Apps remain separate Git repositories. The runner reads/builds/tests arbitrary configured app paths and writes results only inside this repository. It never edits app source. Instrumentation is a separate, explicit change made by invoking the Performance Skill while working in the target app.

The native `packages/ios-core` Swift package owns monotonic timing, process CPU and physical-footprint memory samples, display callback cadence estimates, thermal/app-state snapshots, signposts, and JSON/CSV export. The adapters expose the same scenario/session/mark contract. XCTest supplies launch and test metrics; Instruments/xctrace supplies detailed traces. HTML response/body size and HTML parsing/rendering are not automatically measured; instrument these as separate observed boundaries if the app has such a stage, without exporting HTML content.

## Install the adapters in independent apps

Use local sibling checkouts during development.

### React Native

From the React Native app root:

```sh
npm install ../iOS-Performance/packages/react-native
cd ios && pod install
```

React Native autolinking registers the native module. The adapter currently uses `RCTBridgeModule`; validate New Architecture legacy-module interop against the app's exact React Native version. Minimum iOS is 15.

### Capacitor + Ionic + Angular

From the Capacitor app root:

```sh
npm install ../iOS-Performance/packages/capacitor
npx cap sync ios
```

The adapter supports the repository's Swift Package Manager and CocoaPods integration paths. Build with the Capacitor version used by the app (the adapter targets Capacitor 7–9 APIs) and iOS 15 or later.

For a remote checkout, clone a pinned tag beside the app, then install its adapter folder. Do not install the repository root as an npm dependency: it contains separate packages. Before publishing, replace the podspec's placeholder source URL and use immutable releases.

## Instrument any flow

Use flow-neutral event names based on observed boundaries. The same names must mean the same thing in equivalent apps; framework implementation can differ. The example contract is:

```text
LOGIN
LOGIN_SCREEN_VISIBLE
LOGIN_TAP
AUTH_API
NAVIGATION_START
HOME_VISIBLE
HOME_DATA
HOME_READY
```

Nested sessions such as `AUTH_API` and `HOME_DATA` record service and data loading durations. Use stable technical names only: ASCII letters, digits, `_`, `-`, and `.` (up to 80 characters). Never put user data, account data, tokens, URLs, query strings, headers, payloads, HTML, or error text in event names or attachments.

### React Native example

```ts
import { Performance } from '@ios-performance/react-native';

await Performance.start('LOGIN');
await Performance.mark('LOGIN_SCREEN_VISIBLE');
await Performance.mark('LOGIN_TAP');
await Performance.start('AUTH_API');
try {
  const response = await authService.login(credentials); // existing call
  await Performance.end('AUTH_API');
  await Performance.mark('NAVIGATION_START');
  navigateToHome(response); // existing navigation
} catch (error) {
  await Performance.end('AUTH_API');
  throw error; // retain existing error handling
}
await Performance.mark('HOME_VISIBLE');
await Performance.start('HOME_HTML_SERVICE');
try {
  await existingHomeHtmlServiceCall();
} finally {
  await Performance.end('HOME_HTML_SERVICE');
}
await Performance.mark('HOME_READY');
const result = await Performance.end('LOGIN');
```

### Capacitor + Ionic + Angular example

```ts
import { Performance } from '@ios-performance/capacitor';

await Performance.start({ name: 'LOGIN' });
await Performance.mark({ name: 'LOGIN_SCREEN_VISIBLE' });
await Performance.mark({ name: 'LOGIN_TAP' });
await Performance.start({ name: 'AUTH_API' });
try {
  const response = await existingAuthenticationCall();
  await Performance.end({ name: 'AUTH_API' });
  await Performance.mark({ name: 'NAVIGATION_START' });
  existingNavigateToHome(response);
} catch (error) {
  await Performance.end({ name: 'AUTH_API' });
  throw error;
}
await Performance.mark({ name: 'HOME_VISIBLE' });
await Performance.start({ name: 'HOME_HTML_SERVICE' });
try {
  await existingHomeHtmlServiceCall();
} finally {
  await Performance.end({ name: 'HOME_HTML_SERVICE' });
}
await Performance.mark({ name: 'HOME_READY' });
const result = await Performance.end({ name: 'LOGIN' });
```

For Angular `HttpClient` Observables, instrument at subscription and use RxJS `finalize` to end the nested session. This preserves the original response, error, and completion. Measure the existing service request only; do not add duplicate calls. `HOME_HTML_SERVICE` measures time to receive the existing response, never HTML parsing/content or its URL. Similar labels can cover `fetch`, Axios, GraphQL, or other existing service boundaries. If one app has several calls, give each a stable semantic role and align those roles in its comparison app.

The snippets show placement only. Replace `existing...` names with code discovered in the app. Use actual view-ready/data-ready lifecycle boundaries, preserve cancellation and error semantics, and do not claim instrumentation is a measured result until a benchmark has run.

## Use the Performance Skill from Codex

The Skill is at `skills/ios-performance/SKILL.md` in this repository. To invoke it from an independent app repository, make this Skill available to Codex in that environment (for example, install/copy the file into the configured user skills directory), then start Codex with the target app repository as the workspace. Keep the runner checkout and app checkout independent.

Example agent requests:

```text
Use the ios-performance skill to instrument the login flow in this repository.
Measure the existing authentication and home HTML service calls. Keep event names
semantic, do not log URLs, headers, payloads, HTML or personal data, and validate
the iOS app build if the local setup allows it.
```

```text
Use the ios-performance skill to instrument the product search flow. Discover the
screen, action, existing service calls, results visibility and ready boundary first.
```

The Skill must detect the current framework, inspect the current repository and local changes, confirm the matching adapter and native integration, trace the requested flow, edit only that app when explicitly asked, preserve its behavior, validate where possible, and review the diff for privacy. If the adapter is missing, it reports the exact install/sync steps and installs only when the active environment permits it.

## Configure and run from the console

Prerequisites: macOS with Xcode command line tools, Ruby (standard libraries only for the runner), the relevant app toolchain, a configured simulator/device, and a test target that drives the requested flow. The runner does not install or instrument app dependencies automatically.

From this repository:

```sh
cp performance-projects.yml.example performance-projects.yml
```

Edit `performance-projects.yml` with app-local configuration. Paths are absolute or relative to that YAML file. It contains no credentials and must never contain secrets.

```yaml
projects:
  react-native:
    name: BankApp-RN
    framework: react-native
    path: ../BankApp-ReactNative
    ios:
      workspace: ios/BankApp.xcworkspace # or use project: ios/BankApp.xcodeproj
      scheme: BankApp
      bundleId: com.company.bank.rn
      configuration: Release
      testTarget: BankAppUITests
      test: LoginPerformanceTests/testLogin # optional; defaults to scenario name
      destination: platform=iOS Simulator,id=SIMULATOR-UDID # optional
    results: results/react-native # optional; must remain inside this repository

  capacitor:
    name: BankApp-Capacitor
    framework: capacitor
    path: ../BankApp-Capacitor
    ios:
      workspace: ios/App/App.xcworkspace
      scheme: App
      bundleId: com.company.bank.capacitor
      configuration: Release
      testTarget: AppUITests
      destination: platform=iOS Simulator,id=SIMULATOR-UDID
    results: results/capacitor
```

Supported project settings: local Git checkout path; `react-native` or `capacitor` framework; Xcode `workspace` or `project`; `scheme`; `bundleId`; optional `configuration` (defaults to `Release`), `testTarget`, `test`, `destination`; and `results` directory. There is also a CLI `--destination` override. Do not include signing credentials, API keys, user data, provisioning secrets, or backend passwords. Configure app build secrets through the app's existing secure process, outside this file.

Run one project/scenario, or use the shortcut configured by your local wrapper:

```sh
./scripts/benchmark-project.sh --project react-native --scenario LOGIN --runs 10
./scripts/benchmark-project.sh --project capacitor --scenario LOGIN --runs 10
./scripts/benchmark.sh LOGIN
./scripts/compare.sh LOGIN
```

The project commands resolve and validate each external Git checkout and Xcode container, build the app, run the selected XCTest scenario, export SDK JSON attachments and XCTest metrics, normalize results, and store the batch under `results/`. `benchmark.sh LOGIN` runs every project configured in the YAML for that scenario. Scenario execution requires `ios.testTarget`; it is the UI test's responsibility to drive the same flow and attach the adapter's sanitized `exportJSON()` output. A build alone is not a scenario run.

In an XCTest UI test, trigger the app flow, then retrieve the adapter JSON through the app's existing test bridge (for example, a test-only accessibility/debug hook) and attach that JSON as a file using `XCTAttachment(data: jsonData, uniformTypeIdentifier: "public.json")`. The runner recognizes attachments whose JSON contains SDK `durationMs` and `metrics` fields. Do not expose credentials or user data through the test hook, and do not attach general logs or app state dumps. The exact UI automation and test bridge depend on each host app and belong in that app's test target.

Compare selected projects from the config or supply a comma-separated subset:

```sh
./scripts/compare.sh LOGIN
./scripts/compare.sh --scenario LOGIN --projects react-native,capacitor
```

Comparison reports available SDK duration/process/UI metrics and XCTest metrics separately, with average, median, min, max, P95 and standard deviation. It refuses known mismatched simulator/device destinations. Missing measurements remain missing. The runner does not currently automate `xctrace`; capture and inspect Points of Interest in Instruments separately. Core signposts use subsystem `com.iosperformance.measurements`.

## Privacy and stored results

The SDK stores only bounded technical names, timings, numeric process/UI measurements and coarse OS/build context. It does not read network traffic or serialize request/response data. Event names are validated. The runner redacts common credential formats in captured command logs, filters SDK attachments to an allowlist of measurement fields, and omits local checkout paths, bundle IDs, and device IDs from normalized reports. Keep XCTest attachments limited to SDK result JSON; `.xcresult` is produced by Xcode and may include arbitrary test attachments, so inspect its contents before sharing it. Result directories are ignored by Git by default.

Before sharing benchmark artifacts, inspect them for app-generated attachments, test logs, screenshots, or environment data. Never attach HTML, network dumps, app logs, credentials, tokens, account identifiers, or personal information. Log redaction is a defense in depth measure, not a substitute for avoiding sensitive output in app build scripts or tests.

## Measurements and limits

| Metric | Source | Meaning / limit |
|---|---|---|
| Scenario/service durations and marks | Core | Monotonic elapsed time from native core initialization; service spans include existing request/response wait time |
| CPU current / average / peak | Core | Sampled process CPU time; short spikes may be missed; percentage of one logical CPU |
| Memory start/current/average/peak/end/delta | Core | `phys_footprint` in MiB; samples may miss brief peaks |
| Refresh rate and display callback cadence | Core | Device maximum refresh rate and callback interval estimates, not exact rendered-frame counts |
| Slow frame count | Core estimate; XCTest/Instruments authoritative | Callback intervals longer than 1.5 expected intervals |
| Thermal and app state | Core | State at start, sampled worst thermal state, and end |
| Cold/warm launch and supported performance metrics | XCTest | External launch/test measurements; can cover work before core initialization |
| Detailed CPU, allocations, hitches, Points of Interest | Instruments / xctrace | Trace capture is currently manual |

## Development checks

```sh
cd packages/ios-core && swift test
cd ../..
ruby -c benchmark-runner/benchmark.rb
ruby -c benchmark-runner/compare.rb
bash -n scripts/benchmark.sh scripts/benchmark-project.sh scripts/compare.sh
```

The shared Swift core has host tests. Validate both adapters in their consuming apps before release. No external app checkout needs to be moved or copied into this repository.
