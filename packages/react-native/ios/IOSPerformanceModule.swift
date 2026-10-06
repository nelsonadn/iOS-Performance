import Foundation
import React
import IOSPerformanceCore

@objc(IOSPerformance)
final class IOSPerformanceModule: NSObject, RCTBridgeModule {
  static func moduleName() -> String! { "IOSPerformance" }
  static func requiresMainQueueSetup() -> Bool { false }
  @objc func configure(_ options: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    let interval = options["samplingIntervalMilliseconds"] as? Int ?? 100
    let logging = options["consoleLoggingEnabled"] as? Bool ?? false
    Task { await PerformanceManager.shared.configure(.init(samplingIntervalMilliseconds: interval, consoleLoggingEnabled: logging)); resolve(nil) }
  }
  @objc func start(_ options: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    guard let name = options["name"] as? String else { reject("INVALID_ARGUMENT", "name is required", nil); return }
    Task { do { try await PerformanceManager.shared.start(name); resolve(nil) } catch { reject("START_FAILED", error.localizedDescription, error) } }
  }
  @objc func mark(_ options: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    guard let name = options["name"] as? String else { reject("INVALID_ARGUMENT", "name is required", nil); return }
    Task { do { try await PerformanceManager.shared.mark(name, category: options["category"] as? String ?? "custom"); resolve(nil) } catch { reject("MARK_FAILED", error.localizedDescription, error) } }
  }
  @objc func end(_ options: NSDictionary, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    guard let name = options["name"] as? String else { reject("INVALID_ARGUMENT", "name is required", nil); return }
    Task { do { let result = try await PerformanceManager.shared.end(name); resolve(try JSONSerialization.jsonObject(with: JSONEncoder.performance.encode(result))) } catch { reject("END_FAILED", error.localizedDescription, error) } }
  }
  @objc func snapshot(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) { Task { let value = await PerformanceManager.shared.snapshot(); resolve((try? JSONSerialization.jsonObject(with: JSONEncoder.performance.encode(value))) ?? NSNull()) } }
  @objc func reset(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) { Task { await PerformanceManager.shared.reset(); resolve(nil) } }
  @objc func exportJSON(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) { Task { do { resolve(try await PerformanceManager.shared.exportJSON()) } catch { reject("EXPORT_FAILED", error.localizedDescription, error) } } }
  @objc func exportCSV(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) { Task { resolve(await PerformanceManager.shared.exportCSV()) } }
}

private extension JSONEncoder {
  static var performance: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]; return encoder }
}
