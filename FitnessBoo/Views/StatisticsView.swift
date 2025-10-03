//
//  StatisticsView.swift
//  FitnessBoo
//
//  Created by Claude on 3/10/25.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var nutritionViewModel: NutritionViewModel
    @StateObject private var energyViewModel: EnergyViewModel
    private let healthKitService: HealthKitServiceProtocol
    @State private var selectedPeriod: TimePeriod = .week
    @State private var currentUnitSystem: UnitSystem = .metric
    @State private var selectedDate: Date = Date()
    @State private var historicalData: [DailyNutritionData] = []

    struct DailyNutritionData: Identifiable {
        let id = UUID()
        let date: Date
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalWater: Double = 0
        var mealCount: Int = 0
    }

    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    init(dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(
            dataService: dataService,
            calculationService: calculationService,
            healthKitService: healthKitService
        ))

        self._energyViewModel = StateObject(wrappedValue: EnergyViewModel(
            healthKitService: healthKitService
        ))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Period Selector
                    periodSelector

                    // Summary Cards
                    summarySection

                    // Recent Food Entries
                    foodHistorySection

                    // Weekly Trends
                    trendsSection
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadData()
                loadUnitSystem()
            }
            .onChange(of: selectedPeriod) { _ in
                Task {
                    await loadHistoricalData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnitSystemChanged"))) { notification in
                if let unitSystem = notification.object as? UnitSystem {
                    currentUnitSystem = unitSystem
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.8),
                Color.purple.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 12) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedPeriod == period ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedPeriod == period ?
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) : LinearGradient(
                                colors: [Color(.systemGray6), Color(.systemGray6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.purple)
                Text("Summary")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Text("Last \(selectedPeriod.days) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Avg Calories",
                    value: averageCalories > 0 ? "\(Int(averageCalories))" : "0",
                    subtitle: "per day",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    title: "Avg Protein",
                    value: averageProtein > 0 ? "\(Int(averageProtein))g" : "0g",
                    subtitle: "per day",
                    icon: "leaf.fill",
                    color: .green
                )

                StatCard(
                    title: "Total Meals",
                    value: "\(totalMeals)",
                    subtitle: "logged",
                    icon: "fork.knife",
                    color: .blue
                )

                StatCard(
                    title: "Water Intake",
                    value: averageWater > 0 ? String(format: "%.1fL", averageWater / 1000) : "0L",
                    subtitle: "avg per day",
                    icon: "drop.fill",
                    color: .cyan
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var averageCalories: Double {
        guard !historicalData.isEmpty else { return 0 }
        let total = historicalData.reduce(0) { $0 + $1.totalCalories }
        return total / Double(historicalData.count)
    }

    private var averageProtein: Double {
        guard !historicalData.isEmpty else { return 0 }
        let total = historicalData.reduce(0) { $0 + $1.totalProtein }
        return total / Double(historicalData.count)
    }

    private var averageWater: Double {
        guard !historicalData.isEmpty else { return 0 }
        let total = historicalData.reduce(0) { $0 + $1.totalWater }
        return total / Double(historicalData.count)
    }

    private var totalMeals: Int {
        return historicalData.reduce(0) { $0 + $1.mealCount }
    }

    // MARK: - Food History Section

    private var foodHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.orange)
                Text("Recent Meals")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Text("Last 7 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if nutritionViewModel.foodEntries.isEmpty {
                GlassCard(cornerRadius: 16) {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("No food entries yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Start logging your meals to see history")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(nutritionViewModel.foodEntries.prefix(10)) { entry in
                        FoodHistoryRow(entry: entry)
                    }
                }
            }
        }
    }

    // MARK: - Trends Section

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Text("Calorie Trends")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            GlassCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    if historicalData.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)

                            Text("No data to display")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Start logging meals to see trends")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        let maxCalories = historicalData.map { $0.totalCalories }.max() ?? 1

                        VStack(spacing: 8) {
                            ForEach(Array(historicalData.enumerated()), id: \.element.id) { index, data in
                                HStack(spacing: 12) {
                                    // Date label
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(data.date.formatted(.dateTime.weekday(.abbreviated)))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(data.date.formatted(.dateTime.month().day()))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 50, alignment: .leading)

                                    // Progress bar
                                    GeometryReader { geometry in
                                        let percentage = maxCalories > 0 ? data.totalCalories / maxCalories : 0
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.orange, Color.red],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: max(geometry.size.width * percentage, 20), height: 20)
                                            .overlay(alignment: .leading) {
                                                if data.totalCalories == 0 {
                                                    Text("No data")
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)
                                                        .padding(.leading, 4)
                                                }
                                            }
                                    }
                                    .frame(height: 20)

                                    // Value label
                                    Text("\(Int(data.totalCalories))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(data.totalCalories > 0 ? .primary : .tertiary)
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func loadData() async {
        await nutritionViewModel.loadDailyNutrition()
        await energyViewModel.refreshEnergyData()
        await loadHistoricalData()
    }

    private func loadHistoricalData() async {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) ?? endDate

        var dailyDataMap: [Date: DailyNutritionData] = [:]

        // Initialize all days with zero data
        var currentDate = startDate
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            dailyDataMap[dayStart] = DailyNutritionData(date: dayStart)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }

        // Fetch data from HealthKit for each day
        currentDate = startDate
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            // Fetch calories from HealthKit (errors are handled silently, returns 0)
            let calories = (try? await healthKitService.fetchDietaryEnergy(from: dayStart, to: dayEnd)) ?? 0.0

            // Fetch protein from HealthKit
            let protein = (try? await healthKitService.fetchDietaryProtein(from: dayStart, to: dayEnd)) ?? 0.0

            // Fetch water from HealthKit
            let water = (try? await healthKitService.fetchDietaryWater(from: dayStart, to: dayEnd)) ?? 0.0

            // Update daily data
            if var data = dailyDataMap[dayStart] {
                data.totalCalories = calories
                data.totalProtein = protein
                data.totalWater = water
                dailyDataMap[dayStart] = data
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }

        // Also count meal entries from local database for meal count
        for entry in nutritionViewModel.foodEntries {
            let dayStart = calendar.startOfDay(for: entry.timestamp)

            // Only include entries within our date range
            if dayStart >= calendar.startOfDay(for: startDate) && dayStart <= calendar.startOfDay(for: endDate) {
                if var data = dailyDataMap[dayStart] {
                    data.mealCount += 1
                    dailyDataMap[dayStart] = data
                }
            }
        }

        // Convert to sorted array
        historicalData = dailyDataMap.values.sorted { $0.date < $1.date }
    }

    private func loadUnitSystem() {
        if let savedUnit = UserDefaults.standard.string(forKey: "UnitSystem"),
           let unitSystem = UnitSystem(rawValue: savedUnit) {
            currentUnitSystem = unitSystem
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .foregroundStyle(color)
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct FoodHistoryRow: View {
    let entry: FoodEntry

    var body: some View {
        GlassCard(cornerRadius: 12) {
            HStack(spacing: 12) {
                // Date indicator
                VStack(spacing: 4) {
                    Text(entry.timestamp.formatted(.dateTime.day()))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text(entry.timestamp.formatted(.dateTime.month(.abbreviated)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 50)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                Divider()

                // Entry details
                VStack(alignment: .leading, spacing: 4) {
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else {
                        Text("Food Entry")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Label("\(Int(entry.calories)) cal", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        if let protein = entry.protein, protein > 0 {
                            Label("\(Int(protein))g", systemImage: "leaf.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        if let mealType = entry.mealType {
                            Text(mealType.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(mealColor(for: mealType).opacity(0.2))
                                .foregroundStyle(mealColor(for: mealType))
                                .cornerRadius(4)
                        }
                    }

                    Text(entry.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
        }
    }

    private func mealColor(for type: MealType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
}

// MARK: - Preview

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView(
            dataService: DataService.shared,
            calculationService: CalculationService(),
            healthKitService: HealthKitService()
        )
    }
}
