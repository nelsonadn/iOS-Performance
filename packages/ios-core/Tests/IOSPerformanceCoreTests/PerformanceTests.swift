import XCTest
@testable import IOSPerformanceCore

final class PerformanceTests: XCTestCase {
    func testSessionAndMarkExport() async throws {
        let manager = PerformanceManager()
        try await manager.start("LOGIN")
        try await manager.mark("LOGIN_TAP")
        let result = try await manager.end("LOGIN")
        XCTAssertEqual(result.name, "LOGIN")
        XCTAssertEqual(result.marks.map(\.name), ["LOGIN_TAP"])
        XCTAssertGreaterThanOrEqual(result.durationMs, 0)
    }

    func testIndependentSessionsCanOverlap() async throws {
        let manager = PerformanceManager()
        try await manager.start("FLOW")
        try await manager.start("API")
        let snapshot = await manager.snapshot()
        XCTAssertEqual(snapshot.activeSessions.count, 2)
        _ = try await manager.end("API")
        _ = try await manager.end("FLOW")
    }

    func testDuplicateAndMissingSessionAreReported() async throws {
        let manager = PerformanceManager()
        try await manager.start("ONE")
        do { try await manager.start("ONE"); XCTFail("duplicate start should fail") }
        catch PerformanceError.duplicateSession("ONE") { }
        do { _ = try await manager.end("MISSING"); XCTFail("missing end should fail") }
        catch PerformanceError.missingSession("MISSING") { }
    }

    func testNamesRejectValuesThatCouldContainPersonalData() async throws {
        let manager = PerformanceManager()
        do { try await manager.start("LOGIN-user@example.invalid"); XCTFail("unsafe session name should fail") }
        catch PerformanceError.invalidName { }
        try await manager.start("LOGIN")
        do { try await manager.mark("AUTH_API?token=value"); XCTFail("unsafe mark should fail") }
        catch PerformanceError.invalidName { }
        do { try await manager.mark("AUTH_API", category: "account/123"); XCTFail("unsafe category should fail") }
        catch PerformanceError.invalidName { }
        _ = try await manager.end("LOGIN")
    }

    func testSamplingAndExports() async throws {
        let manager = PerformanceManager()
        await manager.configure(.init(samplingIntervalMilliseconds: 50))
        try await manager.start("SAMPLED")
        try await Task.sleep(nanoseconds: 130_000_000)
        let result = try await manager.end("SAMPLED")
        XCTAssertNotNil(result.metrics.memoryStartMB)
        XCTAssertNotNil(result.metrics.memoryEndMB)
        let json = try await manager.exportJSON()
        XCTAssertTrue(json.contains("SAMPLED"))
        let csv = await manager.exportCSV()
        XCTAssertTrue(csv.contains("scenario,duration_ms"))
        await manager.reset()
        let snapshot = await manager.snapshot()
        XCTAssertTrue(snapshot.completedResults.isEmpty)
    }
}
