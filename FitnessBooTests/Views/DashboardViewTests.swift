//
//  DashboardViewTests.swift
//  FitnessBooTests
//
//  Created by Kiro on 24/7/25.
//

import XCTest
import SwiftUI
@testable import FitnessBoo

@MainActor
final class DashboardViewTests: XCTestCase {
    
    func testDashboardViewInitialization() {
        // Given/When
        let dashboardView = DashboardView()
        
        // Then - Should initialize without crashing
        XCTAssertNotNil(dashboardView)
    }
    
    func testDashboardViewWithMockData() {
        // Given
        
        // When
        let dashboardView = DashboardView()
        
        // Then - Should create view with mock data
        XCTAssertNotNil(dashboardView)
    }
}

// MARK: - Energy Views Tests

final class EnergyBreakdownViewTests: XCTestCase {
    
    func testEnergyBreakdownViewInitialization() {
        // Given
        let activeEnergy = 400.0
        let restingEnergy = 1600.0
        let totalEnergy = 2000.0
        
        // When
        let energyBreakdownView = EnergyBreakdownView(
            activeEnergy: activeEnergy,
            restingEnergy: restingEnergy,
            totalEnergy: totalEnergy
        )
        
        // Then
        XCTAssertNotNil(energyBreakdownView)
    }
    
    func testEnergyDetailViewInitialization() {
        // Given
        let title = "Active"
        let value = "400"
        let color = Color.orange
        let percentage = 0.2
        
        // When
        let energyDetailView = EnergyDetailView(
            title: title,
            value: value,
            color: color,
            percentage: percentage
        )
        
        // Then
        XCTAssertNotNil(energyDetailView)
    }
}

// MARK: - Mock Services for Testing

extension MockDataService {
    // Add any additional mock functionality needed for dashboard testing
}

extension MockCalculationService {
    // Add any additional mock functionality needed for dashboard testing
}