import Foundation
import os
#if canImport(UIKit)
import UIKit
import QuartzCore
#endif
#if canImport(Darwin)
import Darwin
#endif

public enum PerformanceError: Error, LocalizedError {
    case duplicateSession(String)
    case missingSession(String)
    case resetInProgress
    case sessionCancelled(String)
    case invalidName
    public var errorDescription: String? {
        switch self {
        case .duplicateSession(let name): "A session named '\(name)' is already active."
        case .missingSession(let name): "No active session named '\(name)' exists."
        case .resetInProgress: "A reset is in progress; try starting the session again."
        case .sessionCancelled(let name): "Session '\(name)' ended before startup completed."
        case .invalidName: "Names must use 1–80 ASCII letters, digits, underscores, periods, or hyphens."
        }
    }
}

public struct PerformanceConfiguration: Sendable {
    public var samplingIntervalMilliseconds: Int
    public var consoleLoggingEnabled: Bool
    public init(samplingIntervalMilliseconds: Int = 100, consoleLoggingEnabled: Bool = false) {
        self.samplingIntervalMilliseconds = [50, 100, 250, 500, 1000].contains(samplingIntervalMilliseconds) ? samplingIntervalMilliseconds : 100
        self.consoleLoggingEnabled = consoleLoggingEnabled
    }
}

public struct PerformanceMark: Codable, Sendable {
    public let name: String
    public let offsetMs: Double
    public let category: String
}

public struct MetricSamples: Codable, Sendable {
    public let cpuCurrentPercent: Double?
    public let cpuAveragePercent: Double?
    public let cpuPeakPercent: Double?
    public let memoryStartMB: Double?
    public let memoryCurrentMB: Double?
    public let memoryAverageMB: Double?
    public let memoryPeakMB: Double?
    public let memoryEndMB: Double?
    public let memoryDeltaMB: Double?
    public let refreshRate: Double?
    public let averageFPS: Double?
    public let minimumObservedFPS: Double?
    public let frameCount: Int?
    public let slowFrameCount: Int?
    public let frameTimeAverageMs: Double?
    public let frameTimeMaxMs: Double?
    public let thermalStateStart: String
    public let thermalStateWorst: String
    public let thermalStateEnd: String
}

public struct PerformanceResult: Codable, Sendable {
    public let name: String
    public let startTimestamp: Date
    public let endTimestamp: Date
    public let durationMs: Double
    public let marks: [PerformanceMark]
    public let metrics: MetricSamples
    public let applicationStateStart: String
    public let applicationStateEnd: String
    public let metadata: [String: String]
}

public struct PerformanceSnapshot: Codable, Sendable {
    public let activeSessions: [String]
    public let completedResults: [PerformanceResult]
}

private struct Sample: Sendable {
    let time: TimeInterval
    let cpu: Double?
    let memory: Double?
}

private struct ActiveSession: Sendable {
    let name: String
    let startClock: TimeInterval
    let startDate: Date
    let cpuStart: Double?
    let memoryStart: Double?
    let thermalStart: String
    var applicationStateStart: String
    var frameBaseline: Int
    var marks: [PerformanceMark] = []
    var samples: [Sample] = []
    var worstThermal: String
}

private struct FrameMetrics: Sendable {
    let count: Int
    let averageFPS: Double?
    let minimumFPS: Double?
    let slowCount: Int
    let averageFrameTimeMs: Double?
    let maximumFrameTimeMs: Double?
}

#if canImport(UIKit)
@MainActor
private final class FrameLinkTarget: NSObject {
    weak var probe: FrameProbe?
    @objc func tick(_ link: CADisplayLink) { probe?.record(link.timestamp, expectedInterval: link.targetTimestamp - link.timestamp) }
}

private struct FrameTick {
    let timestamp: CFTimeInterval
    let expectedInterval: CFTimeInterval
}

@MainActor
private final class FrameProbe {
    static let shared = FrameProbe()
    private var link: CADisplayLink?
    private var target: FrameLinkTarget?
    private var activeSessions = 0
    private var timestamps: [FrameTick] = []

    func begin() -> Int {
        activeSessions += 1
        if link == nil {
            timestamps.removeAll(keepingCapacity: true)
            let callback = FrameLinkTarget()
            callback.probe = self
            target = callback
            let displayLink = CADisplayLink(target: callback, selector: #selector(FrameLinkTarget.tick(_:)))
            displayLink.add(to: .main, forMode: .common)
            link = displayLink
        }
        return timestamps.count
    }

    func record(_ timestamp: CFTimeInterval, expectedInterval: CFTimeInterval) { timestamps.append(FrameTick(timestamp: timestamp, expectedInterval: expectedInterval)) }

    func metrics(since baseline: Int) -> FrameMetrics {
        guard timestamps.count > baseline + 1 else { return FrameMetrics(count: max(0, timestamps.count - baseline), averageFPS: nil, minimumFPS: nil, slowCount: 0, averageFrameTimeMs: nil, maximumFrameTimeMs: nil) }
        let start = max(0, baseline)
        let pairs = zip(timestamps[start..<(timestamps.count - 1)], timestamps[(start + 1)...])
        let intervals = pairs.map { (elapsed: $1.timestamp - $0.timestamp, expected: $0.expectedInterval) }.filter { $0.elapsed > 0 }
        guard !intervals.isEmpty else { return FrameMetrics(count: 0, averageFPS: nil, minimumFPS: nil, slowCount: 0, averageFrameTimeMs: nil, maximumFrameTimeMs: nil) }
        let total = intervals.reduce(0) { $0 + $1.elapsed }
        let longest = intervals.map(\.elapsed).max() ?? total
        return FrameMetrics(count: intervals.count, averageFPS: Double(intervals.count) / total, minimumFPS: 1 / longest, slowCount: intervals.filter { $0.expected > 0 && $0.elapsed > ($0.expected * 1.5) }.count, averageFrameTimeMs: total / Double(intervals.count) * 1000, maximumFrameTimeMs: longest * 1000)
    }

    func end() {
        activeSessions = max(0, activeSessions - 1)
        if activeSessions == 0 { link?.invalidate(); link = nil; target = nil; timestamps.removeAll(keepingCapacity: false) }
    }

    func reset() { activeSessions = 0; link?.invalidate(); link = nil; target = nil; timestamps.removeAll(keepingCapacity: false) }
}
#endif

/// Shared, framework-independent in-process iOS performance measurement engine.
public actor PerformanceManager {
    public static let shared = PerformanceManager()
    private let log = OSLog(subsystem: "com.iosperformance.measurements", category: .pointsOfInterest)
    private var configuration = PerformanceConfiguration()
    private var sessions: [String: ActiveSession] = [:]
    private var signpostIDs: [String: OSSignpostID] = [:]
    private var completed: [PerformanceResult] = []
    private var sampler: Task<Void, Never>?
    private var previousCPU: (time: TimeInterval, cpuSeconds: Double)?
    private var resetInProgress = false

    public func configure(_ configuration: PerformanceConfiguration) {
        self.configuration = configuration
    }

    @discardableResult
    public func start(_ name: String) async throws -> Bool {
        guard Self.isSafeName(name) else { throw PerformanceError.invalidName }
        guard !resetInProgress else { throw PerformanceError.resetInProgress }
        guard sessions[name] == nil else { throw PerformanceError.duplicateSession(name) }
        let now = ProcessInfo.processInfo.systemUptime
        let memory = Self.physicalFootprintMB()
        let thermal = Self.thermalName(ProcessInfo.processInfo.thermalState)
        sessions[name] = ActiveSession(name: name, startClock: now, startDate: Date(), cpuStart: nil, memoryStart: memory, thermalStart: thermal, applicationStateStart: "unknown", frameBaseline: 0, worstThermal: thermal)
        let signpostID = OSSignpostID(log: log)
        signpostIDs[name] = signpostID
        os_signpost(.begin, log: log, name: "PerformanceSession", signpostID: signpostID, "%{public}s", name)
        addPoint("\(name)_START", category: "flow")
        if sampler == nil { startSampler() }
        #if canImport(UIKit)
        let frameBaseline = await FrameProbe.shared.begin()
        #else
        let frameBaseline = 0
        #endif
        let applicationState = await Self.applicationState()
        guard var session = sessions[name], !resetInProgress else { throw PerformanceError.sessionCancelled(name) }
        session.frameBaseline = frameBaseline
        session.applicationStateStart = applicationState
        sessions[name] = session
        return true
    }

    public func mark(_ name: String, category: String = "custom") throws {
        guard Self.isSafeName(name), Self.isSafeName(category) else { throw PerformanceError.invalidName }
        let now = ProcessInfo.processInfo.systemUptime
        guard !sessions.isEmpty else { return }
        for key in Array(sessions.keys) {
            guard var session = sessions[key] else { continue }
            session.marks.append(PerformanceMark(name: name, offsetMs: (now - session.startClock) * 1000, category: category))
            sessions[key] = session
        }
        addPoint(name, category: category)
    }

    @discardableResult
    public func end(_ name: String) async throws -> PerformanceResult {
        guard let session = sessions.removeValue(forKey: name) else { throw PerformanceError.missingSession(name) }
        let endClock = ProcessInfo.processInfo.systemUptime
        let memoryEnd = Self.physicalFootprintMB()
        let refreshRate = await Self.refreshRate()
        let metadata = await Self.metadata()
        let applicationStateEnd = await Self.applicationState()
        let thermalEnd = Self.thermalName(ProcessInfo.processInfo.thermalState)
        let thermalWorst = Self.thermalRank(thermalEnd) > Self.thermalRank(session.worstThermal) ? thermalEnd : session.worstThermal
        let frameMetrics: FrameMetrics?
        #if canImport(UIKit)
        frameMetrics = await FrameProbe.shared.metrics(since: session.frameBaseline)
        #else
        frameMetrics = nil
        #endif
        if let id = signpostIDs.removeValue(forKey: name) { os_signpost(.end, log: log, name: "PerformanceSession", signpostID: id, "%{public}s", name) }
        let samples = session.samples
        let cpuValues = samples.compactMap(\.cpu)
        let memoryValues = samples.compactMap(\.memory)
        let result = PerformanceResult(
            name: name, startTimestamp: session.startDate, endTimestamp: Date(), durationMs: (endClock - session.startClock) * 1000,
            marks: session.marks,
            metrics: MetricSamples(
                cpuCurrentPercent: cpuValues.last, cpuAveragePercent: Self.average(cpuValues), cpuPeakPercent: cpuValues.max(),
                memoryStartMB: session.memoryStart, memoryCurrentMB: memoryEnd, memoryAverageMB: Self.average(memoryValues), memoryPeakMB: memoryValues.max(), memoryEndMB: memoryEnd,
                memoryDeltaMB: (memoryEnd != nil && session.memoryStart != nil) ? memoryEnd! - session.memoryStart! : nil,
                refreshRate: refreshRate, averageFPS: frameMetrics?.averageFPS, minimumObservedFPS: frameMetrics?.minimumFPS, frameCount: frameMetrics?.count, slowFrameCount: frameMetrics?.slowCount,
                frameTimeAverageMs: frameMetrics?.averageFrameTimeMs, frameTimeMaxMs: frameMetrics?.maximumFrameTimeMs,
                thermalStateStart: session.thermalStart, thermalStateWorst: thermalWorst, thermalStateEnd: thermalEnd
            ), applicationStateStart: session.applicationStateStart, applicationStateEnd: applicationStateEnd, metadata: metadata)
        completed.append(result)
        #if canImport(UIKit)
        await FrameProbe.shared.end()
        #endif
        if sessions.isEmpty { sampler?.cancel(); sampler = nil }
        if configuration.consoleLoggingEnabled { PerformanceLogger.print(result) }
        return result
    }

    public func snapshot() -> PerformanceSnapshot { PerformanceSnapshot(activeSessions: sessions.keys.sorted(), completedResults: completed) }
    public func reset() async {
        guard !resetInProgress else { return }
        resetInProgress = true
        for (name, id) in signpostIDs { os_signpost(.end, log: log, name: "PerformanceSession", signpostID: id, "%{public}s", name) }
        sessions.removeAll(); signpostIDs.removeAll(); completed.removeAll(); sampler?.cancel(); sampler = nil; previousCPU = nil
        #if canImport(UIKit)
        await FrameProbe.shared.reset()
        #endif
        resetInProgress = false
    }
    public func exportJSON(pretty: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let data = try encoder.encode(completed)
        return String(decoding: data, as: UTF8.self)
    }
    public func exportCSV() -> String {
        var rows = ["scenario,duration_ms,cpu_avg,cpu_peak,memory_avg_mb,memory_peak_mb,fps_avg,slow_frames"]
        rows += completed.map { result in
            let m = result.metrics
            return [Self.csv(result.name), Self.num(result.durationMs), Self.num(m.cpuAveragePercent), Self.num(m.cpuPeakPercent), Self.num(m.memoryAverageMB), Self.num(m.memoryPeakMB), Self.num(m.averageFPS), ""].joined(separator: ",")
        }
        return rows.joined(separator: "\n")
    }

    private func startSampler() {
        let interval = configuration.samplingIntervalMilliseconds
        sampler = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000)
                guard !Task.isCancelled else { break }
                await self?.sampleNow()
            }
        }
    }
    private func sampleNow() {
        let now = ProcessInfo.processInfo.systemUptime
        let cpuSeconds = Self.processCPUSeconds()
        let cpu: Double?
        if let prior = previousCPU, let cpuSeconds, now > prior.time {
            cpu = max(0, (cpuSeconds - prior.cpuSeconds) / (now - prior.time) * 100)
        } else { cpu = nil }
        if let cpuSeconds { previousCPU = (now, cpuSeconds) }
        let memory = Self.physicalFootprintMB()
        for key in Array(sessions.keys) {
            guard var value = sessions[key] else { continue }
            value.samples.append(Sample(time: now, cpu: cpu, memory: memory))
            let thermal = Self.thermalName(ProcessInfo.processInfo.thermalState)
            if Self.thermalRank(thermal) > Self.thermalRank(value.worstThermal) { value.worstThermal = thermal }
            sessions[key] = value
        }
    }
    private func addPoint(_ name: String, category: String) {
        let pointLog = OSLog(subsystem: "com.iosperformance.measurements", category: category)
        os_signpost(.event, log: pointLog, name: "PerformanceMark", "%{public}s", name)
    }
    private static func processCPUSeconds() -> Double? {
        #if canImport(Darwin)
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        let current = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        return current >= 0 ? current : nil
        #else
        return nil
        #endif
    }
    private static func physicalFootprintMB() -> Double? {
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return status == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : nil
        #else
        return nil
        #endif
    }
    @MainActor private static func refreshRate() -> Double? {
        #if canImport(UIKit)
        return Double(UIScreen.main.maximumFramesPerSecond)
        #else
        return nil
        #endif
    }
    @MainActor private static func applicationState() -> String {
        #if canImport(UIKit)
        switch UIApplication.shared.applicationState { case .active: "active"; case .inactive: "inactive"; case .background: "background"; @unknown default: "unknown" }
        #else
        "unknown"
        #endif
    }
    private static func thermalName(_ state: ProcessInfo.ThermalState) -> String { switch state { case .nominal: "nominal"; case .fair: "fair"; case .serious: "serious"; case .critical: "critical"; @unknown default: "unknown" } }
    private static func thermalRank(_ state: String) -> Int { ["nominal": 0, "fair": 1, "serious": 2, "critical": 3][state] ?? -1 }
    @MainActor private static func metadata() -> [String: String] {
        var values = ["simulator": "\(isSimulator)"]
        let version = ProcessInfo.processInfo.operatingSystemVersion
        values["osVersion"] = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, Self.isSafeName(version) { values["appVersion"] = version }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, Self.isSafeName(build) { values["buildVersion"] = build }
        #if canImport(UIKit)
        values["deviceModel"] = UIDevice.current.model
        #endif
        return values
    }
    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
    private static func average(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    private static func isSafeName(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 80 else { return false }
        return value.utf8.allSatisfy { byte in
            (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) || byte == 95 || byte == 45 || byte == 46
        }
    }
    private static func num(_ value: Double?) -> String { value.map { String(format: "%.3f", $0) } ?? "" }
    private static func csv(_ value: String) -> String { "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" }
}

public enum PerformanceLogger {
    public static func print(_ result: PerformanceResult) {
        Swift.print("iOS Performance | \(result.name) | \(String(format: "%.1f", result.durationMs)) ms")
        for mark in result.marks { Swift.print(String(format: "  %@ +%.1f ms", mark.name, mark.offsetMs)) }
    }
}
