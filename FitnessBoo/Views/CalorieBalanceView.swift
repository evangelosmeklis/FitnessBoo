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
        VStack(spacing: 12) {
            // Main balance display
            VStack(spacing: 4) {
                Text(balance.formattedBalance)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(balance.isPositiveBalance ? .orange : .green)
                
                Text(balance.balanceDescription)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Balance equation
            HStack(spacing: 8) {
                VStack {
                    Text("\(Int(balance.caloriesConsumed))")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Consumed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Text("−")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text("\(Int(balance.totalEnergyExpended))")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Burned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Text("=")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text("\(Int(balance.balance))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(balance.isPositiveBalance ? .orange : .green)
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Energy Breakdown Section
    private func energyBreakdownSection(balance: CalorieBalance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                energyRow(
                    title: "Resting Energy",
                    value: balance.restingEnergyBurned,
                    color: .blue,
                    icon: "bed.double.fill"
                )
                
                energyRow(
                    title: "Active Energy",
                    value: balance.activeEnergyBurned,
                    color: .red,
                    icon: "flame.fill"
                )
                
                Divider()
                
                energyRow(
                    title: "Total Burned",
                    value: balance.totalEnergyExpended,
                    color: .primary,
                    icon: "sum",
                    isTotal: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func energyRow(title: String, value: Double, color: Color, icon: String, isTotal: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .semibold : .regular)
            
            Spacer()
            
            Text("\(Int(value)) kcal")
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .semibold : .medium)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Data Source Section
    private func dataSourceSection(balance: CalorieBalance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: balance.isUsingHealthKitData ? "heart.fill" : "calculator")
                    .foregroundColor(balance.isUsingHealthKitData ? .red : .blue)
                
                Text("Data Source")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(balance.energySourceDescription)
                .font(.body)
                .foregroundColor(.secondary)
            
            if balance.isUsingHealthKitData {
                Text("Using real-time data from Health app for maximum accuracy")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Using calculated BMR (Calculated: \(Int(balance.calculatedBMR)) kcal)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Connect to Health app for more accurate tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
}