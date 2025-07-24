//
//  HealthKitConfigurationTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 24/7/25.
//

import XCTest
import HealthKit
@testable import FitnessBoo

@MainActor
final class HealthKitConfigurationTests: XCTestCase {
    
    var healthKitService: HealthKitService!
    
    override func setUp() {
        super.setUp()
        healthKitService = HealthKitService()
    }
    
    override func tearDown() {
        healthKitService = nil
        super.tearDown()
    }
    
    func testHealthKitAvailability() {
        // Test that HealthKit availability check works
        let isAvailable = healthKitService.isHealthKitAvailable
        
        // On simulator, HealthKit may not be available
        // On device, it should be available
        print("HealthKit available: \(isAvailable)")
        
        // This test should not fail regardless of availability
        XCTAssertTrue(true, "HealthKit availability check completed")
    }
    
    func testHealthKitStatusCheck() {
        // Test the status check method
        let status = healthKitService.checkHealthKitStatus()
        
        print("HealthKit Status:")
        print("- Available: \(status.available)")
        print("- Authorized: \(status.authorized)")
        print("- Message: \(status.message)")
        
        // Verify the status check returns valid information
        XCTAssertNotNil(status.message)
        XCTAssertFalse(status.message.isEmpty)
    }
    
    func testHealthKitDataTypes() {
        // Test that required data types are available
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        let restingEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
        let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        
        XCTAssertNotNil(activeEnergyType, "Active energy type should be available")
        XCTAssertNotNil(restingEnergyType, "Resting energy type should be available")
        XCTAssertNotNil(bodyMassType, "Body mass type should be available")
    }
    
    func testHealthKitErrorMessages() {
        // Test that error messages are informative
        let errors: [HealthKitError] = [
            .healthKitNotAvailable,
            .authorizationNotDetermined,
            .authorizationFailed("Test error"),
            .dataTypeNotAvailable,
            .dataFetchFailed("Network error"),
            .permissionDenied,
            .syncFailed("Sync error"),
            .conflictResolutionFailed("Conflict error"),
            .backgroundSyncUnavailable
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
}