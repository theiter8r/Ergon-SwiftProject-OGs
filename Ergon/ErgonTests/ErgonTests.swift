//
//  ErgonTests.swift
//  ErgonTests
//
//  Created by Raaj  Patkar on 17/04/26.
//

import XCTest
@testable import Ergon

final class ErgonTests: XCTestCase {

    func testBurnoutAnalyzerPrediction() async throws {
        let analyzer = await BurnoutAnalyzer()
        
        // High risk scenario: low sleep, low HRV, high calendar density
        await analyzer.predictRisk(sleepHours: 4.5, hrv: 35.0, calendarDensity: 9.0)
        
        // Wait for analysis to finish (it has a built-in sleep of 0.8s)
        XCTAssertFalse(analyzer.isAnalyzing)
        XCTAssertNotEqual(analyzer.currentRisk, "Unknown")
        XCTAssertNotEqual(analyzer.currentRisk, "Error")
        
        // In this hardcoded scenario, we expect "High" risk
        XCTAssertEqual(analyzer.currentRisk, "High")
    }

    func testPerformancePrediction() async {
        let analyzer = await BurnoutAnalyzer()
        
        measure {
            let expectation = expectation(description: "Prediction")
            Task {
                await analyzer.predictRisk(sleepHours: 7.5, hrv: 65.0, calendarDensity: 2.0)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)
        }
    }
}

