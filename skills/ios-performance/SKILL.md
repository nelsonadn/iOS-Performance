---
name: ios-performance
description: Instrument, inspect, remove, or review user flow performance in the current independent React Native or Capacitor/Ionic/Angular iOS application using @ios-performance adapters.
---

# iOS Performance Instrumentation

This skill works in the current target application repository, even when `iOS-Performance` is a separate checkout. Never assume a monorepo, app/repo name, source directory, scheme, screen, service, or bundle identifier.

## Request handling

Handle requests to instrument a named flow, instrument only API or rendering, instrument all primary flows, show existing instrumentation, or remove instrumentation for a flow. For edits, discover the entire flow first and then make minimal code changes. Never change request payloads, error handling, navigation behavior, or business logic. Do not log credentials, tokens, personal data, account data, request URLs, query strings, headers, bodies, or response content. SDK event/session/category names must contain only ASCII letters, digits, `_`, `-`, and `.` (maximum 80 characters); use static technical labels only.

## Repository discovery

1. Inspect the current repository instructions and working tree. Identify package manager, source files, and existing local changes; preserve unrelated work.
2. Detect framework using manifests and native project shape: React Native (`react-native` dependency and RN app entry), or Capacitor (`@capacitor/core`, `capacitor.config.*`, and usually Ionic/Angular manifests). If ambiguous, inspect native iOS plugin registration and ask only if the framework still cannot be determined.
3. Verify the matching dependency and native iOS plugin are installed. React Native requires `@ios-performance/react-native`; Capacitor requires `@ios-performance/capacitor`. Check lockfile and generated iOS project / CocoaPods integration. If missing, explain the exact local or published installation command and perform installation only when package manager/network use is authorized in the active session. Run `pod install` or `npx cap sync ios` when part of the requested setup and available.
4. Read adapter API documentation from the dependency or its source. Never add calls to a guessed package API.

## Trace the requested flow

Find the entry screen, user action, validation boundaries, service/API calls, async completion, navigation, destination visibility, data loading, and best available interactive-ready point. Use targeted search and inspect call sites. Do not add marks to every function. If a reliable ready point cannot be determined, state that limitation and use the closest observable boundary.

Use shared semantic event names across equivalent app implementations. For login, preferred boundaries are `LOGIN`, `LOGIN_SCREEN_VISIBLE`, `LOGIN_TAP`, `AUTH_API_START`, `AUTH_API_END`, `NAVIGATION_START`, `HOME_VISIBLE`, `HOME_DATA_START`, `HOME_DATA_END`, and `HOME_READY`. Name nested sessions for meaningful work such as `AUTH_API` or `HOME_DATA`; marks use the same labels on each framework. Only create marks while a parent session is active.

### Instrument service and HTML requests

Find the existing service method called by the flow. Wrap the existing call itself with a nested session named for its semantic role, for example `AUTH_API`, `HOME_HTML_SERVICE`, or `HOME_DATA_SERVICE`. This captures total request/response wait time. Keep event vocabulary equivalent in both apps even when one uses `fetch`, Axios, Angular `HttpClient`, or an HTML endpoint. Do not infer timing from a screen transition or add a second request. Record status only if the flow already observes it, and use a bounded category such as `success`, `client_error`, `server_error`, or `network_error`; never record response text, content, headers, full URL, route parameters, query string, account/user ID, or exception message. For HTML services, the metric is elapsed time of the existing HTML service request and completion; response HTML must never be exported.

Preserve original errors and subscription semantics. A small helper may isolate measurement failures so instrumentation cannot fail the business operation:

```ts
async function measured<T>(label: string, operation: () => Promise<T>): Promise<T> {
  try { await Performance.start(label); } catch { /* measurement only */ }
  try {
    return await operation();
  } finally {
    try { await Performance.end(label); } catch { /* measurement only */ }
  }
}
```

Use this around the already-existing service call; don’t pass request data into `label`.

React Native service example:

```ts
const result = await measured('AUTH_API', () => authService.login(credentials));
```

Capacitor + Ionic + Angular `HttpClient` example:

```ts
const result = await firstValueFrom(measuredObservable(
  'HOME_HTML_SERVICE',
  this.http.get<ExistingResponse>(existingHtmlServiceUrl, existingOptions)
));
```

`measuredObservable` should start on subscription and end in RxJS `finalize`, preserving the original Observable value/error/completion. The service URL and options above are existing app values; neither is read or serialized by instrumentation. If the flow has multiple independent services, add a stable session per service role and keep the same roles across implementations.

### React Native form

```ts
import { Performance } from '@ios-performance/react-native';
// await Performance.start('LOGIN')
// await Performance.mark('LOGIN_TAP')
// await Performance.start('AUTH_API')
// await Performance.end('AUTH_API')
// await Performance.end('LOGIN')
```

### Capacitor form

```ts
import { Performance } from '@ios-performance/capacitor';
// await Performance.start({ name: 'LOGIN' })
// await Performance.mark({ name: 'LOGIN_TAP' })
// await Performance.start({ name: 'AUTH_API' })
// await Performance.end({ name: 'AUTH_API' })
// await Performance.end({ name: 'LOGIN' })
```

Put calls immediately around observed boundaries. Ensure async cleanup/end behavior is consistent with the existing flow and does not replace, reorder, or swallow application errors. Do not await instrumentation in a way that changes user-visible ordering if that would alter behavior; adapter calls should be fire-and-observe where needed, with failures isolated from app behavior.

## Show and remove

For “show” requests, locate existing calls and report their surrounding flow without edits. For removal, remove only instrumentation introduced for the named flow; preserve shared setup and calls used by other flows. Review diffs to ensure app behavior is untouched.

## Privacy review

Before finishing, inspect the diff for event names containing dynamic interpolation, URLs, query strings, credentials, request/response serialization, or user/account fields. Inspect generated config and result examples for secret values. Keep the runner config free of secrets; use normal app secret provisioning outside the benchmark config. Attach only the SDK's sanitized result JSON to XCTest. Never attach app logs, network dumps, HTML, request/response fixtures, screenshots with user data, or environment dumps. If privacy cannot be established for an existing instrumentation path, remove or narrow that path before reporting.

## Validation and report

Run the narrowest compilation/type check available when requested and practical. Report detected flow, event/session names, files changed, adapter verification, and validation. Call out boundaries that could not be established. For show/remove requests, report what was found or removed. Never claim a measurement has run merely because instrumentation was added.
