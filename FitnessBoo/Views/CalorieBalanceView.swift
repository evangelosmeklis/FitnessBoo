//
//  CalorieBalanceView.swift
//  FitnessBoo
//
//  Created by Kiro on 24/7/25.
//

import SwiftUI
import Combine

struct CalorieBalanceView: View {
    @StateObject private var viewModel: CalorieBalanceViewModel
    
    init(calorieBalanceService: CalorieBalanceServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: CalorieBalanceViewModel(calorieBalanceService: calorieBalanceService))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            
            if let balance = viewModel.currentBalance {
                balanceCardSection(balance: balance)
                energyBreakdownSection(balance: balance)
                dataSourceSection(balance: balance)
            } else {
                loadingSection
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Calorie Balance")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.startTracking()
        }
        .onDisappear {
            viewModel.stopTracking()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Today's Balance")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Real-time caloric tracking")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Balance Card Section
    private func balanceCardSection(balance: CalorieBalance) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 16) {
                // Main balance display
                VStack(spacing: 8) {
                    Text(balance.balanceDescription.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)

                    Text(balance.formattedBalance)
                        .font(.system(size: 44, weight: .medium, design: .rounded))
                        .foregroundColor(balance.isPositiveBalance ? .premiumCoral : .premiumMint)
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                // Balance equation
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Text("\(Int(balance.caloriesConsumed))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Consumed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Text("−")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        Text("\(Int(balance.totalEnergyExpended))")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Burned")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Text("=")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        Text("\(Int(balance.balance))")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(balance.isPositiveBalance ? .premiumCoral : .premiumMint)
                        Text("Balance")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Energy Breakdown Section
    private func energyBreakdownSection(balance: CalorieBalance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENERGY BREAKDOWN")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1.5)

            GlassCard(cornerRadius: 20) {
                VStack(spacing: 0) {
                    HorizontalMetricRow(
                        icon: "moon.stars.fill",
                        label: "Resting",
                        value: "\(Int(balance.restingEnergyBurned))",
                        unit: "kcal",
                        progress: nil,
                        color: .premiumSky
                    )

                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.vertical, 8)

                    HorizontalMetricRow(
                        icon: "figure.run",
                        label: "Active",
                        value: "\(Int(balance.activeEnergyBurned))",
                        unit: "kcal",
                        progress: nil,
                        color: .premiumMint
                    )

                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.vertical, 8)

                    HorizontalMetricRow(
                        icon: "flame.fill",
                        label: "Total",
                        value: "\(Int(balance.totalEnergyExpended))",
                        unit: "kcal",
                        progress: nil,
                        color: .premiumCoral
                    )
                }
            }
        }
    }
    
    // MARK: - Data Source Section
    private func dataSourceSection(balance: CalorieBalance) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(balance.isUsingHealthKitData ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: balance.isUsingHealthKitData ? "heart.fill" : "calculator")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(balance.isUsingHealthKitData ? .green : .blue)
                        )

                    Text("DATA SOURCE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }

                Text(balance.energySourceDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if balance.isUsingHealthKitData {
                    Text("Using real-time data from Health app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("BMR: \(Int(balance.calculatedBMR)) kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 16) {
            SwiftUI.ProgressView()
                .scaleEffect(1.2)
            
            Text("Calculating balance...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - CalorieBalanceViewModel
@MainActor
class CalorieBalanceViewModel: ObservableObject {
    @Published var currentBalance: CalorieBalance?
    @Published var isLoading = false
    
    private let calorieBalanceService: CalorieBalanceServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(calorieBalanceService: CalorieBalanceServiceProtocol) {
        self.calorieBalanceService = calorieBalanceService
        setupObservers()
    }
    
    func startTracking() {
        isLoading = true
        calorieBalanceService.startRealTimeTracking()
    }
    
    func stopTracking() {
        calorieBalanceService.stopRealTimeTracking()
    }
    
    private func setupObservers() {
        calorieBalanceService.currentBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.currentBalance = balance
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }
}

// MARK: - Preview
struct CalorieBalanceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CalorieBalanceView(calorieBalanceService: MockCalorieBalanceService())
        }
    }
}

// MARK: - Mock Service for Previews
class MockCalorieBalanceService: CalorieBalanceServiceProtocol {
    var currentBalance: AnyPublisher<CalorieBalance?, Never> {
        Just(CalorieBalance(
            date: Date(),
            caloriesConsumed: 1800,
            restingEnergyBurned: 1600,
            activeEnergyBurned: 400,
            totalEnergyBurned: 2000,
            calculatedBMR: 1650,
            balance: -200,
            isUsingHealthKitData: true
        )).eraseToAnyPublisher()
    }
    
    var isTracking: Bool = false
    
    func startRealTimeTracking() {}
    func stopRealTimeTracking() {}
    func getCurrentBalance() async -> CalorieBalance? { nil }
    func getBalanceForDate(_ date: Date) async -> CalorieBalance? { nil }
    func getDailyGoalAdjustment() async -> Double { return -308.0 }
}