# React Native adapter

Install from an independent app checkout with `npm install ../iOS-Performance/packages/react-native`, then run `cd ios && pod install`. The package delegates all measurements to the shared Swift core. Its native bridge uses `RCTBridgeModule`; React Native New Architecture apps rely on the legacy module interop layer. A generated TurboModule/codegen interface is not included in this initial adapter.

The adapter requires iOS 15+. Its React Native peer version is intentionally broad because the implementation uses the established bridge protocol, but real host-project builds across React Native versions remain to be validated.
