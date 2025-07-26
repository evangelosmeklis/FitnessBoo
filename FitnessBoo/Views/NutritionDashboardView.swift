//
//  NutritionDashboardView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI

struct NutritionDashboardView: View {
    @StateObject private var nutritionViewModel: NutritionViewModel
    @StateObject private var calorieBalanceService: CalorieBalanceService
    @State private var showingAddFood = false
    @State private var selectedEntry: FoodEntry?
    @State private var showingEditFood = false
    @State private var currentBalance: CalorieBalance?
    @State private var dailyGoalAdjustment: Double = 0.0
    
    init(dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(
            dataService: dataService,
            calculationService: calculationService,
            healthKitService: healthKitService
        ))
        
        self._calorieBalanceService = StateObject(wrappedValue: CalorieBalanceService(
            healthKitService: healthKitService,
            calculationService: calculationService,
            dataService: dataService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Daily Progress Section
                    dailyProgressSection
                    
                    // Quick Stats Grid
                    quickStatsGrid
                    
                    // Water Tracking Section
                    waterTrackingSection
                    
                    // Food Entries by Meal Type
                    foodEntriesSection
                    
                    Spacer(minLength: 100) // Space for floating action button
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await nutritionViewModel.refreshData()
            }
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button with Glass Effect
                GlassButton("Add Food", icon: "plus", style: .blue) {
                    showingAddFood = true
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
                currentBalance = await calorieBalanceService.getCurrentBalance()
                dailyGoalAdjustment = await calorieBalanceService.getDailyGoalAdjustment()
            }
            .onAppear {
                Task {
                    await nutritionViewModel.loadDailyNutrition()
                    await nutritionViewModel.refreshData()
                    currentBalance = await calorieBalanceService.getCurrentBalance()
                    dailyGoalAdjustment = await calorieBalanceService.getDailyGoalAdjustment()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))) { _ in
                Task {
                    await nutritionViewModel.refreshData()
                    currentBalance = await calorieBalanceService.getCurrentBalance()
                    dailyGoalAdjustment = await calorieBalanceService.getDailyGoalAdjustment()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WeightDataUpdated"))) { _ in
                Task {
                    await nutritionViewModel.refreshData()
                    currentBalance = await calorieBalanceService.getCurrentBalance()
                    dailyGoalAdjustment = await calorieBalanceService.getDailyGoalAdjustment()
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
                Color.green.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Daily Progress Section
    
    private var dailyProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                VStack(spacing: 16) {
                    // Caloric Balance
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Caloric Balance")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text({
                                if let balance = currentBalance {
                                    let sign = balance.balance >= 0 ? "+" : ""
                                    let type = balance.balance >= 0 ? "surplus" : "deficit"
                                    return "\(sign)\(Int(balance.balance)) kcal \(type)"
                                }
                                return "Loading..."
                            }())
                                .font(.caption)
                                .foregroundStyle((currentBalance?.isPositiveBalance ?? false) ? .green : .red)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(nutritionViewModel.totalCalories)) cal")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text("consumed today")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Protein Progress
                    NutritionProgressRow(
                        title: "Protein",
                        current: Int(nutritionViewModel.totalProtein),
                        target: Int(nutritionViewModel.dailyNutrition?.proteinTarget ?? 100),
                        unit: "g",
                        color: .green,
                        icon: "leaf.fill"
                    )
                }
            }
        }
    }
    
    // MARK: - Quick Stats Grid
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Daily Goal",
                value: {
                    if let balance = currentBalance {
                        let currentSign = balance.balance >= 0 ? "+" : ""
                        let goalSign = dailyGoalAdjustment >= 0 ? "+" : ""
                        return "\(currentSign)\(Int(balance.balance)) / \(goalSign)\(Int(dailyGoalAdjustment))"
                    }
                    return "Loading..."
                }(),
                subtitle: {
                    if let balance = currentBalance {
                        let currentBalanceValue = balance.balance
                        let difference = currentBalanceValue - dailyGoalAdjustment
                        
                        print("🎯 Daily Goal Debug: Current=\(currentBalanceValue), Goal=\(dailyGoalAdjustment), Difference=\(difference)")
                        
                        if abs(difference) < 50 {
                            return "Goal achieved!"
                        } else if difference < 0 {
                            // Need more deficit/surplus
                            if dailyGoalAdjustment < 0 {
                                return "Burn \(Int(abs(difference))) more calories"
                            } else {
                                return "Eat \(Int(abs(difference))) more calories"
                            }
                        } else {
                            // Too much deficit/surplus
                            if dailyGoalAdjustment < 0 {
                                return "Eat \(Int(difference)) more calories"
                            } else {
                                return "Burn \(Int(difference)) more calories"
                            }
                        }
                    }
                    return "Loading..."
                }(),
                icon: "target",
                color: {
                    if let balance = currentBalance {
                        let currentBalanceValue = balance.balance
                        let difference = abs(currentBalanceValue - dailyGoalAdjustment)
                        
                        if difference < 50 { return .green }
                        else if difference < 150 { return .orange }
                        else { return .red }
                    }
                    return .blue
                }(),
                progress: {
                    if let balance = currentBalance {
                        let currentBalanceValue = balance.balance
                        let progress = abs(dailyGoalAdjustment) > 0 ? min(abs(currentBalanceValue) / abs(dailyGoalAdjustment), 2.0) / 2.0 : 0.5
                        return progress
                    }
                    return 0.0
                }()
            )
            
            MetricCard(
                title: "Protein Left",
                value: "\(Int(nutritionViewModel.remainingProtein))g",
                subtitle: "remaining today",
                icon: "leaf.fill",
                color: .green,
                progress: nutritionViewModel.proteinProgress
            )
        }
    }
    
    // MARK: - Water Tracking Section
    
    @State private var showingCustomWaterInput = false
    @State private var customWaterAmount = ""
    
    private var waterTrackingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Water Intake")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Water")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("\(Int(nutritionViewModel.totalWater)) / \(Int(nutritionViewModel.dailyWaterTarget)) ml")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        CircularProgressView(
                            progress: nutritionViewModel.waterProgress,
                            color: .blue
                        )
                        .frame(width: 40, height: 40)
                    }
                    
                    Divider()
                    
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
            }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Meals")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if !nutritionViewModel.foodEntries.isEmpty {
                    Text("\(nutritionViewModel.foodEntries.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if nutritionViewModel.foodEntries.isEmpty {
                GlassCard {
                    emptyStateContent
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        let entries = nutritionViewModel.entriesByMealType[mealType] ?? []
                        if !entries.isEmpty {
                            GlassCard {
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
    }
    
    private var emptyStateContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No meals logged today")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Tap 'Add Food' to start tracking your nutrition")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WeightDataUpdated"))) { _ in
            Task {
                // Reload goal data when weight changes
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

// MARK: - Supporting Views

struct NutritionProgressRow: View {
    let title: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color
    let icon: String
    
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(current) / \(target) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                
                SwiftUI.ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(width: 60)
            }
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