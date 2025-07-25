//
//  ProgressView.swift
//  FitnessBoo
//
//  Created by Kiro on 24/7/25.
//

import SwiftUI
import HealthKit
import Combine

struct ProgressView: View {
    @StateObject private var viewModel: ProgressViewModel
    
    init(dataService: DataServiceProtocol = DataService.shared,
         calculationService: CalculationServiceProtocol = CalculationService(),
         healthKitService: HealthKitServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: ProgressViewModel(
            dataService: dataService,
            calculationService: calculationService,
            healthKitService: healthKitService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Weekly Progress Section
                    weeklyProgressSection
                    
                    // Overall Progress Section
                    overallProgressSection
                    
                    // Daily Progress Chart
                    dailyProgressChart
                    
                    // Progress Insights
                    progressInsights
                }
                .padding()
            }
            .navigationTitle("Progress")
            .refreshable {
                await viewModel.refreshData()
            }
            .task {
                await viewModel.loadProgressData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nutritionDataUpdated)) { _ in
                Task {
                    await viewModel.refreshData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))) { _ in
                Task {
                    await viewModel.refreshData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WeightDataUpdated"))) { _ in
                Task {
                    await viewModel.refreshData()
                }
            }
        }
    }
    
    // MARK: - Weekly Progress Section
    
    private var weeklyProgressSection: some View {
        VStack(spacing: 16) {
            HStack {
                Label("This Week's Progress", systemImage: "calendar.badge.clock")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Text("Week \(viewModel.currentWeekNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Weekly Progress Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Weekly Deficit/Surplus")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.weeklyCalorieBalance >= 0 ? "+" : "")\(Int(viewModel.weeklyCalorieBalance)) kcal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.weeklyCalorieBalance < 0 ? .red : .green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target Weekly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.weeklyTargetCalorieBalance >= 0 ? "+" : "")\(Int(viewModel.weeklyTargetCalorieBalance)) kcal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.weeklyTargetCalorieBalance < 0 ? .red : .green)
                    }
                }
                
                Divider()
                
                // Progress Status
                HStack {
                    Image(systemName: viewModel.isOnTrackWeekly ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.isOnTrackWeekly ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.weeklyProgressStatus)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(viewModel.weeklyProgressDetails)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Overall Progress Section
    
    private var overallProgressSection: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Overall Progress to Goal", systemImage: "target")
                    .font(.headline)
                    .foregroundColor(.purple)
                Spacer()
                if let daysRemaining = viewModel.daysRemainingToGoal {
                    Text("\(daysRemaining) days left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Overall Progress Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.totalCalorieBalance >= 0 ? "+" : "")\(Int(viewModel.totalCalorieBalance)) kcal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.totalCalorieBalance < 0 ? .red : .green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.totalTargetCalorieBalance >= 0 ? "+" : "")\(Int(viewModel.totalTargetCalorieBalance)) kcal")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.totalTargetCalorieBalance < 0 ? .red : .green)
                    }
                }
                
                // Progress Bar
                SwiftUI.ProgressView(value: viewModel.overallProgressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: viewModel.overallProgressPercentage >= 1.0 ? .green : .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    Text("\(Int(viewModel.overallProgressPercentage * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.overallProgressStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.isOnTrackOverall ? .green : .orange)
                }
                
                Divider()
                
                Text(viewModel.overallProgressDetails)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Daily Progress Chart
    
    private var dailyProgressChart: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Daily Balance Trend", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            
            // Simple chart placeholder for now
            VStack {
                Text("Daily Progress Chart")
                    .font(.headline)
                    .padding()
                
                if !viewModel.dailyProgressData.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.dailyProgressData.suffix(7), id: \.date) { data in
                                VStack(spacing: 4) {
                                    Text("\(Int(data.cumulativeBalance))")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                    
                                    Rectangle()
                                        .fill(data.cumulativeBalance >= data.targetCumulativeBalance ? Color.green : Color.red)
                                        .frame(width: 20, height: max(10, abs(data.cumulativeBalance) / 100))
                                    
                                    Text(data.date, format: .dateTime.weekday(.abbreviated))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("No data available yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 100)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Progress Insights
    
    private var progressInsights: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Insights & Recommendations", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.insights, id: \.self) { insight in
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(insight)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    ProgressView(healthKitService: ProgressMockHealthKitService())
}

// Mock service for preview
private class ProgressMockHealthKitService: HealthKitServiceProtocol {
    var isHealthKitAvailable: Bool = true
    var authorizationStatus: HKAuthorizationStatus = .sharingAuthorized
    var lastSyncDate: Date? = Date()
    var syncStatus: AnyPublisher<SyncStatus, Never> {
        return Combine.Just(SyncStatus.success(Date())).eraseToAnyPublisher()
    }
    
    func requestAuthorization() async throws { }
    func saveDietaryEnergy(calories: Double, date: Date) async throws { }
    func saveWater(milliliters: Double, date: Date) async throws { }
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] { return [] }
    func fetchActiveEnergy(for date: Date) async throws -> Double { return 400 }
    func fetchRestingEnergy(for date: Date) async throws -> Double { return 1600 }
    func fetchTotalEnergyExpended(for date: Date) async throws -> Double { return 2000 }
    func fetchWeight() async throws -> Double? { return 70.0 }
    func observeWeightChanges() -> AnyPublisher<Double, Never> {
        return Combine.Just(70.0).eraseToAnyPublisher()
    }
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never> {
        return Combine.Just([]).eraseToAnyPublisher()
    }
    func observeEnergyChanges() -> AnyPublisher<(resting: Double, active: Double), Never> {
        return Combine.Just((resting: 1600.0, active: 400.0)).eraseToAnyPublisher()
    }
    func manualRefresh() async throws { }
    func startBackgroundSync() { }
    func stopBackgroundSync() { }
}