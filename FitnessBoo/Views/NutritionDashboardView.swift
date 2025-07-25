//
//  NutritionDashboardView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI

struct NutritionDashboardView: View {
    @StateObject private var nutritionViewModel: NutritionViewModel
    @State private var showingAddFood = false
    @State private var selectedEntry: FoodEntry?
    @State private var showingEditFood = false
    
    init(dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(
            dataService: dataService,
            calculationService: calculationService,
            healthKitService: healthKitService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Daily Progress Section
                    dailyProgressSection
                    
                    // Quick Add Button
                    quickAddButton
                    
                    // Water Tracking Section
                    waterTrackingSection
                    
                    // Food Entries by Meal Type
                    foodEntriesSection
                    
                    Spacer(minLength: 100) // Space for floating action button
                }
                .padding()
            }
            .navigationTitle("Nutrition")
            .refreshable {
                await nutritionViewModel.refreshData()
            }
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button
                Button {
                    showingAddFood = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showingAddFood) {
                FoodEntryView(nutritionViewModel: nutritionViewModel)
            }
            .sheet(item: $selectedEntry) { entry in
                FoodEntryView(nutritionViewModel: nutritionViewModel, existingEntry: entry)
            }
            .task {
                await nutritionViewModel.loadDailyNutrition()
            }
            .onAppear {
                Task {
                    await nutritionViewModel.loadDailyNutrition()
                    await nutritionViewModel.refreshData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))) { _ in
                Task {
                    await nutritionViewModel.refreshData()
                }
            }
        }
    }
    
    // MARK: - Daily Progress Section
    
    private var dailyProgressSection: some View {
        VStack(spacing: 16) {
            Text("Today's Progress")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // Caloric Balance Progress
                CaloricBalanceCard()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Add Button
    
    private var quickAddButton: some View {
        Button {
            showingAddFood = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Log Food")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Water Tracking Section
    
    @State private var showingCustomWaterInput = false
    @State private var customWaterAmount = ""
    
    private var waterTrackingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Water Intake")
                    .font(.headline)
                Spacer()
                Text("\(Int(nutritionViewModel.totalWater)) ml")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 8) {
                WaterButton(amount: 250) {
                    Task { await nutritionViewModel.addWater(milliliters: 250) }
                }
                WaterButton(amount: 500) {
                    Task { await nutritionViewModel.addWater(milliliters: 500) }
                }
                WaterButton(amount: 750) {
                    Task { await nutritionViewModel.addWater(milliliters: 750) }
                }
                
                Button("Custom") {
                    showingCustomWaterInput = true
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Add Water", isPresented: $showingCustomWaterInput) {
            TextField("Amount (ml)", text: $customWaterAmount)
                .keyboardType(.numberPad)
            Button("Add") {
                if let amount = Double(customWaterAmount), amount > 0 {
                    Task { await nutritionViewModel.addWater(milliliters: amount) }
                }
                customWaterAmount = ""
            }
            Button("Cancel", role: .cancel) {
                customWaterAmount = ""
            }
        } message: {
            Text("Enter the amount of water in milliliters")
        }
    }
    
    // MARK: - Food Entries Section
    
    private var foodEntriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Meals")
                    .font(.headline)
                Spacer()
                if !nutritionViewModel.foodEntries.isEmpty {
                    Text("\(nutritionViewModel.foodEntries.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Debug info

            
            if nutritionViewModel.foodEntries.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        let entries = nutritionViewModel.entriesByMealType[mealType] ?? []
                        if !entries.isEmpty {
                            MealSection(
                                mealType: mealType,
                                entries: entries,
                                onEntryTapped: { entry in
                                    selectedEntry = entry
                                },
                                onEntryDeleted: { entry in
                                    Task {
                                        await nutritionViewModel.deleteFoodEntry(entry)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No meals logged today")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap the + button to start tracking your nutrition")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Progress Card

struct ProgressCard: View {
    let title: String
    let current: Double
    let target: Double
    let remaining: Double
    let progress: Double
    let color: Color
    let icon: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(current))/\(Int(target)) \(unit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            SwiftUI.ProgressView(value: min(progress, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            HStack {
                if remaining > 0 {
                    Text("\(Int(remaining)) \(unit) remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Target achieved!")
                        .font(.caption)
                        .foregroundColor(color)
                        .fontWeight(.medium)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(progress >= 1.0 ? color : .secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Meal Section

struct MealSection: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let onEntryTapped: (FoodEntry) -> Void
    let onEntryDeleted: (FoodEntry) -> Void
    
    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Meal header
            HStack {
                Label(mealType.displayName, systemImage: mealType.icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(totalCalories)) cal")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Food entries
            ForEach(entries) { entry in
                FoodEntryRow(entry: entry) {
                    onEntryTapped(entry)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        onEntryDeleted(entry)
                    }
                }
            }
        }
    }
}

// MARK: - Food Entry Row

struct FoodEntryRow: View {
    let entry: FoodEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(Int(entry.calories)) cal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(entry.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Water Button

struct WaterButton: View {
    let amount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(amount) ml")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
    }
}

// MARK: - Caloric Balance Card

struct CaloricBalanceCard: View {
    @StateObject private var calorieBalanceService: CalorieBalanceService
    @StateObject private var goalViewModel: GoalViewModel
    @State private var currentBalance: CalorieBalance?
    
    init() {
        let healthKitService = HealthKitService()
        let calculationService = CalculationService()
        let dataService = DataService.shared
        
        self._calorieBalanceService = StateObject(wrappedValue: CalorieBalanceService(
            healthKitService: healthKitService,
            calculationService: calculationService,
            dataService: dataService
        ))
        
        self._goalViewModel = StateObject(wrappedValue: GoalViewModel(
            calculationService: calculationService,
            dataService: dataService,
            healthKitService: healthKitService
        ))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Caloric Balance", systemImage: "scale.3d")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("vs Target")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Current Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(currentBalance?.balance ?? 0)) cal")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(balanceColor)
                    Text("Consumed: \(Int(currentBalance?.caloriesConsumed ?? 0))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Target Adjustment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(adjustmentText)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(targetColor)
                    
                }
            }
            
            // Progress indicator
            let progress = calculateProgress()
            SwiftUI.ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            calorieBalanceService.startRealTimeTracking()
            Task {
                // Load the current goal for the user (this populates the UI fields)
                if let user = try? await DataService.shared.fetchUser() {
                    await goalViewModel.loadCurrentGoal(for: user)
                }
            }
        }
        .onReceive(calorieBalanceService.currentBalance) { balance in
            currentBalance = balance
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))) { _ in
            Task {
                // Reload the current goal when goals are updated
                if let user = try? await DataService.shared.fetchUser() {
                    await goalViewModel.loadCurrentGoal(for: user)
                }
            }
        }
    }
    
    private var balanceColor: Color {
        let balance = currentBalance?.balance ?? 0
        return balance < 0 ? .red : .green
    }
    
    private var targetColor: Color {
        let adjustment = goalViewModel.calculatedDailyCalorieAdjustment
        return adjustment < 0 ? .red : .green
    }
    
    private var adjustmentText: String {
        let adjustment = goalViewModel.calculatedDailyCalorieAdjustment
        if adjustment == 0 {
            return "No target"
        }
        return "\(adjustment > 0 ? "+" : "")\(Int(adjustment)) cal"
    }
    
    private func calculateProgress() -> Double {
        let currentBalanceValue = currentBalance?.balance ?? 0
        let targetAdjustment = goalViewModel.calculatedDailyCalorieAdjustment
        
        if targetAdjustment == 0 { return 0.5 }
        
        // For weight loss (negative target), we want current balance to be more negative
        // For weight gain (positive target), we want current balance to be more positive
        if targetAdjustment < 0 {
            // Weight loss: progress is good when current balance is more negative than target
            return min(max(abs(currentBalanceValue) / abs(targetAdjustment), 0), 2) / 2
        } else {
            // Weight gain: progress is good when current balance matches positive target
            return min(max(currentBalanceValue / targetAdjustment, 0), 2) / 2
        }
    }
    
    private var progressColor: Color {
        let progress = calculateProgress()
        if progress > 0.8 { return .green }
        if progress > 0.5 { return .orange }
        return .red
    }
    
    private var statusText: String {
        let currentBalanceValue = currentBalance?.balance ?? 0
        let targetAdjustment = goalViewModel.calculatedDailyCalorieAdjustment
        
        if targetAdjustment == 0 {
            return "No active goal set"
        }
        
        let difference = abs(currentBalanceValue) - abs(targetAdjustment)
        
        if targetAdjustment < 0 { // Weight loss
            if currentBalanceValue <= targetAdjustment {
                return "Great! You're on track for weight loss"
            } else {
                return "Need \(Int(abs(difference))) more calorie deficit"
            }
        } else { // Weight gain
            if currentBalanceValue >= targetAdjustment {
                return "Great! You're on track for weight gain"
            } else {
                return "Need \(Int(difference)) more calorie surplus"
            }
        }
    }
    
    private var statusColor: Color {
        let currentBalanceValue = currentBalance?.balance ?? 0
        let targetAdjustment = goalViewModel.calculatedDailyCalorieAdjustment
        
        if targetAdjustment == 0 { return .secondary }
        
        if targetAdjustment < 0 { // Weight loss
            return currentBalanceValue <= targetAdjustment ? .green : .orange
        } else { // Weight gain
            return currentBalanceValue >= targetAdjustment ? .green : .orange
        }
    }
}

// MARK: - Preview

struct NutritionDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionDashboardView(
            dataService: MockDataService(),
            calculationService: MockCalculationService(),
            healthKitService: MockHealthKitService()
        )
    }
}