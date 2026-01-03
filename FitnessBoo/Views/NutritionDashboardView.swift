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
    @StateObject private var goalViewModel: GoalViewModel
    @State private var showingAddFood = false
    @State private var selectedEntry: FoodEntry?
    @State private var showingEditFood = false
    @State private var currentBalance: CalorieBalance?
    @State private var dailyGoalAdjustment: Double = 0.0
    @State private var currentUnitSystem: UnitSystem = .metric
    
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
        
        self._goalViewModel = StateObject(wrappedValue: GoalViewModel(
            calculationService: calculationService,
            dataService: dataService,
            healthKitService: healthKitService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
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
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await nutritionViewModel.refreshData()
            }
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button with Glass Effect
                GlassButton("Add Food", icon: "plus", style: .blue) {
                    showingAddFood = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 120)
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
                
                // Load goal data first to get proper calculation
                if let user = try? await DataService.shared.fetchUser() {
                    await goalViewModel.loadCurrentGoal(for: user)
                }
                dailyGoalAdjustment = goalViewModel.calculatedDailyCalorieAdjustment
            }
            .onAppear {
                Task {
                    await nutritionViewModel.loadDailyNutrition()
                    await nutritionViewModel.refreshData()
                    currentBalance = await calorieBalanceService.getCurrentBalance()
                    
                    // Load goal data first to get proper calculation
                    if let user = try? await DataService.shared.fetchUser() {
                        await goalViewModel.loadCurrentGoal(for: user)
                    }
                    dailyGoalAdjustment = goalViewModel.calculatedDailyCalorieAdjustment
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GoalUpdated"))) { _ in
                Task {
                    await nutritionViewModel.refreshData()
                    currentBalance = await calorieBalanceService.getCurrentBalance()
                    
                    // Reload goal data when goal updates
                    if let user = try? await DataService.shared.fetchUser() {
                        await goalViewModel.loadCurrentGoal(for: user)
                    }
                    dailyGoalAdjustment = goalViewModel.calculatedDailyCalorieAdjustment
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WeightDataUpdated"))) { _ in
                Task {
                    await nutritionViewModel.refreshData()
                    currentBalance = await calorieBalanceService.getCurrentBalance()
                    
                    // Reload goal data when weight updates
                    if let user = try? await DataService.shared.fetchUser() {
                        await goalViewModel.loadCurrentGoal(for: user)
                    }
                    dailyGoalAdjustment = goalViewModel.calculatedDailyCalorieAdjustment
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
        ZStack {
            // Navy blue base
            Color(red: 0.04, green: 0.08, blue: 0.15)
                .ignoresSafeArea()
            
            // Subtle gradient overlays
            LinearGradient(
                colors: [
                    Color.green.opacity(0.05),
                    Color.clear,
                    Color.cyan.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Daily Progress Section
    
    private var dailyProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.green)
                Text("Today's Progress")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            GlassCard(cornerRadius: 20) {
                VStack(spacing: 20) {
                    // Calories Consumed - Large Display
                    VStack(spacing: 8) {
                        Text("Calories Consumed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(nutritionViewModel.totalCalories))")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("kcal")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                        }

                        // Balance Status
                        HStack(spacing: 6) {
                            Image(systemName: (currentBalance?.isPositiveBalance ?? false) ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle((currentBalance?.isPositiveBalance ?? false) ? .green : .red)
                                .font(.caption)

                            Text({
                                if let balance = currentBalance {
                                    let sign = balance.balance >= 0 ? "+" : ""
                                    let type = balance.balance >= 0 ? "surplus" : "deficit"
                                    return "\(sign)\(Int(balance.balance)) kcal \(type)"
                                }
                                return "Calculating..."
                            }())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle((currentBalance?.isPositiveBalance ?? false) ? .green : .red)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background((currentBalance?.isPositiveBalance ?? false) ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Divider()

                    // Protein Progress Row
                    EnhancedNutritionProgressRow(
                        title: "Protein",
                        current: Int(nutritionViewModel.totalProtein),
                        target: Int(nutritionViewModel.dailyNutrition?.proteinTarget ?? 100),
                        unit: currentUnitSystem == .metric ? "g" : "oz",
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
                        
                        if abs(difference) < 50 {
                            return "Goal achieved!"
                        } else {
                            let diffSign = difference >= 0 ? "+" : ""
                            return "\(diffSign)\(Int(difference)) cal vs goal"
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
    
    @State private var showingWaterOptions = false
    @State private var showingCustomWaterInput = false
    @State private var customWaterAmount = ""
    
    private var waterTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.circle.fill")
                    .foregroundStyle(.blue)
                Text("Water Intake")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            GlassCard(cornerRadius: 20) {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                                .frame(width: 70, height: 70)

                            Circle()
                                .trim(from: 0, to: min(nutritionViewModel.waterProgress, 1.0))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 70, height: 70)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: nutritionViewModel.waterProgress)

                            VStack(spacing: 2) {
                                Text("\(Int(nutritionViewModel.waterProgress * 100))%")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today's Water")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(nutritionViewModel.totalWater))")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("/ \(Int(nutritionViewModel.dailyWaterTarget)) ml")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text("\(Int(nutritionViewModel.dailyWaterTarget - nutritionViewModel.totalWater)) ml remaining")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }

                    Divider()

                    GlassButton("Log Water", icon: "drop.fill", style: .blue) {
                        showingWaterOptions = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingWaterOptions) {
            WaterOptionsSheet(
                onWaterAdded: { amount in
                    Task { await nutritionViewModel.addWater(milliliters: amount) }
                    showingWaterOptions = false
                },
                onCustomWater: {
                    showingCustomWaterInput = true
                }
            )
            .presentationDetents([.medium])
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Today's Meals")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                if !nutritionViewModel.foodEntries.isEmpty {
                    Text("\(nutritionViewModel.foodEntries.count) entries")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            if nutritionViewModel.foodEntries.isEmpty {
                GlassCard(cornerRadius: 20) {
                    emptyStateContent
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        let entries = nutritionViewModel.entriesByMealType[mealType] ?? []
                        if !entries.isEmpty {
                            GlassCard(cornerRadius: 16) {
                                EnhancedMealSection(
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

// MARK: - Enhanced Meal Section

struct EnhancedMealSection: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let onEntryTapped: (FoodEntry) -> Void
    let onEntryDeleted: (FoodEntry) -> Void

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Meal header with gradient background
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(mealColor.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: mealType.icon)
                            .foregroundStyle(mealColor)
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text(mealType.displayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(totalCalories))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(mealColor)
                        Text("cal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 4)

            // Food entries
            ForEach(entries) { entry in
                EnhancedFoodEntryRow(entry: entry) {
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

    private var mealColor: Color {
        switch mealType {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
}

// MARK: - Enhanced Food Entry Row

struct EnhancedFoodEntryRow: View {
    let entry: FoodEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Calorie badge
                VStack(spacing: 2) {
                    Text("\(Int(entry.calories))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("cal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)

                // Entry details
                VStack(alignment: .leading, spacing: 4) {
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    } else {
                        Text("Food Entry")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(entry.formattedTime)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        if let protein = entry.protein, protein > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "leaf.fill")
                                    .font(.caption2)
                                Text("\(Int(protein))g")
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground).opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
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

struct EnhancedNutritionProgressRow: View {
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Text("\(current)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                    Text("/ \(target) \(unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Preview

// MARK: - Water Options Sheet

struct WaterOptionsSheet: View {
    let onWaterAdded: (Double) -> Void
    let onCustomWater: () -> Void
    
    private let waterAmounts = [250, 330, 500, 750, 1000]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Text("Select Water Amount")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(waterAmounts, id: \.self) { amount in
                            GlassCard {
                                VStack(spacing: 8) {
                                    Image(systemName: "drop.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                    
                                    Text("\(amount) ml")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text(getAmountDescription(amount))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 8)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onWaterAdded(Double(amount))
                            }
                        }
                        
                        // Custom amount option
                        GlassCard {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                
                                Text("Custom")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Enter your own amount")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onCustomWater()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // This will be handled by the parent view
                    }
                }
            }
        }
    }
    
    private func getAmountDescription(_ amount: Int) -> String {
        switch amount {
        case 250: return "Small glass"
        case 330: return "Can/small bottle"
        case 500: return "Standard bottle"
        case 750: return "Large bottle"
        case 1000: return "1 liter bottle"
        default: return "Custom amount"
        }
    }
}

struct NutritionDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionDashboardView(
            dataService: MockDataService(),
            calculationService: MockCalculationService(),
            healthKitService: MockHealthKitService()
        )
    }
}