import Foundation
import Capacitor
#if canImport(IOSPerformanceCore)
import IOSPerformanceCore
#endif

@objc(IOSPerformancePlugin)
public class IOSPerformancePlugin: CAPPlugin, CAPBridgedPlugin {
  public let identifier = "IOSPerformancePlugin"
  public let jsName = "IOSPerformance"
  public let pluginMethods: [CAPPluginMethod] = [
    CAPPluginMethod(name: "configure", returnType: CAPPluginReturnPromise), CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
    CAPPluginMethod(name: "mark", returnType: CAPPluginReturnPromise), CAPPluginMethod(name: "end", returnType: CAPPluginReturnPromise),
    CAPPluginMethod(name: "snapshot", returnType: CAPPluginReturnPromise), CAPPluginMethod(name: "reset", returnType: CAPPluginReturnPromise),
    CAPPluginMethod(name: "exportJSON", returnType: CAPPluginReturnPromise), CAPPluginMethod(name: "exportCSV", returnType: CAPPluginReturnPromise)
  ]
  @objc func configure(_ call: CAPPluginCall) { let interval = call.getInt("samplingIntervalMilliseconds") ?? 100; let logging = call.getBool("consoleLoggingEnabled") ?? false; Task { await PerformanceManager.shared.configure(.init(samplingIntervalMilliseconds: interval, consoleLoggingEnabled: logging)); call.resolve() } }
  @objc func start(_ call: CAPPluginCall) { guard let name = call.getString("name") else { call.reject("name is required"); return }; Task { do { try await PerformanceManager.shared.start(name); call.resolve() } catch { call.reject(error.localizedDescription) } } }
  @objc func mark(_ call: CAPPluginCall) { guard let name = call.getString("name") else { call.reject("name is required"); return }; let category = call.getString("category") ?? "custom"; Task { do { try await PerformanceManager.shared.mark(name, category: category); call.resolve() } catch { call.reject(error.localizedDescription) } } }
  @objc func end(_ call: CAPPluginCall) { guard let name = call.getString("name") else { call.reject("name is required"); return }; Task { do { let result = try await PerformanceManager.shared.end(name); let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; call.resolve(try JSONSerialization.jsonObject(with: encoder.encode(result)) as? [String:Any] ?? [:]) } catch { call.reject(error.localizedDescription) } } }
  @objc func snapshot(_ call: CAPPluginCall) { Task { let value = await PerformanceManager.shared.snapshot(); let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; do { call.resolve(try JSONSerialization.jsonObject(with: encoder.encode(value)) as? [String:Any] ?? [:]) } catch { call.reject(error.localizedDescription) } } }
  @objc func reset(_ call: CAPPluginCall) { Task { await PerformanceManager.shared.reset(); call.resolve() } }
  @objc func exportJSON(_ call: CAPPluginCall) { Task { do { call.resolve(["value": try await PerformanceManager.shared.exportJSON()]) } catch { call.reject(error.localizedDescription) } } }
  @objc func exportCSV(_ call: CAPPluginCall) { Task { call.resolve(["value": await PerformanceManager.shared.exportCSV()]) } }
}
