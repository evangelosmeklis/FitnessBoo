//
//  FoodEntryView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI
import Combine
import HealthKit

struct FoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var nutritionViewModel: NutritionViewModel
    @StateObject private var mealCacheService = MealCacheService()

    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fats: String = ""
    @State private var saturatedFats: String = ""
    @State private var mealName: String = ""
    @State private var selectedMealType: MealType = .snack
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    @State private var isLoading = false
    @State private var currentUnitSystem: UnitSystem = .metric
    @State private var searchText = ""
    @State private var showingMealSelector = false
    @State private var saveMeal = false
    
    // For editing existing entries
    private let existingEntry: FoodEntry?
    private let isEditing: Bool
    
    init(nutritionViewModel: NutritionViewModel, existingEntry: FoodEntry? = nil) {
        self.nutritionViewModel = nutritionViewModel
        self.existingEntry = existingEntry
        self.isEditing = existingEntry != nil
        
        // Initialize with existing entry data if editing
        if let entry = existingEntry {
            _calories = State(initialValue: String(format: "%.0f", entry.calories))
            _protein = State(initialValue: entry.protein != nil ? String(format: "%.1f", entry.protein!) : "")
            _carbs = State(initialValue: entry.carbs != nil ? String(format: "%.1f", entry.carbs!) : "")
            _fats = State(initialValue: entry.fats != nil ? String(format: "%.1f", entry.fats!) : "")
            _saturatedFats = State(initialValue: entry.saturatedFats != nil ? String(format: "%.1f", entry.saturatedFats!) : "")
            _selectedMealType = State(initialValue: entry.mealType ?? MealType.suggestedMealType())
            _mealName = State(initialValue: entry.notes ?? "")  // Use notes as meal name
        } else {
            _selectedMealType = State(initialValue: MealType.suggestedMealType())
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Quick Meal Selection Section
                    if !isEditing {
                        quickMealSelectionSection
                    }

                    // Food Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Food Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        GlassCard {
                            VStack(spacing: 16) {
                                // Calories input
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                        .frame(width: 24, height: 24)
                                    
                                    Text("Calories")
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    TextField("0", text: $calories)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    
                                    Text("kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Divider()

                                // Protein input (optional)
                                HStack {
                                    Image(systemName: "leaf.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                        .frame(width: 24, height: 24)

                                    Text("Protein")
                                        .font(.subheadline)

                                    Spacer()

                                    TextField("Optional", text: $protein)
                                        .keyboardType(.decimalPad)
                                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: protein) { newValue in
                                            // Replace comma with period for decimal input
                                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                                            if correctedValue != newValue {
                                                protein = correctedValue
                                            }
                                        }

                                    Text(currentUnitSystem == .metric ? "g" : "oz")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                // Carbs input (optional)
                                HStack {
                                    Image(systemName: "carrot.fill")
                                        .font(.title2)
                                        .foregroundStyle(.yellow)
                                        .frame(width: 24, height: 24)

                                    Text("Carbs")
                                        .font(.subheadline)

                                    Spacer()

                                    TextField("Optional", text: $carbs)
                                        .keyboardType(.decimalPad)
                                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: carbs) { newValue in
                                            // Replace comma with period for decimal input
                                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                                            if correctedValue != newValue {
                                                carbs = correctedValue
                                            }
                                        }

                                    Text(currentUnitSystem == .metric ? "g" : "oz")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                // Fats input (optional)
                                HStack {
                                    Image(systemName: "drop.fill")
                                        .font(.title2)
                                        .foregroundStyle(.pink)
                                        .frame(width: 24, height: 24)

                                    Text("Fats")
                                        .font(.subheadline)

                                    Spacer()

                                    TextField("Optional", text: $fats)
                                        .keyboardType(.decimalPad)
                                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: fats) { newValue in
                                            // Replace comma with period for decimal input
                                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                                            if correctedValue != newValue {
                                                fats = correctedValue
                                            }
                                        }

                                    Text(currentUnitSystem == .metric ? "g" : "oz")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                // Saturated Fats input (optional, subcategory of fats)
                                HStack {
                                    Image(systemName: "drop.triangle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)
                                        .frame(width: 24, height: 24)

                                    Text("Sat. Fats")
                                        .font(.subheadline)

                                    Spacer()

                                    TextField("Optional", text: $saturatedFats)
                                        .keyboardType(.decimalPad)
                                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: saturatedFats) { newValue in
                                            // Replace comma with period for decimal input
                                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                                            if correctedValue != newValue {
                                                saturatedFats = correctedValue
                                            }
                                        }

                                    Text(currentUnitSystem == .metric ? "g" : "oz")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                // Meal name input
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                        .frame(width: 24, height: 24)

                                    Text("Meal Name")
                                        .font(.subheadline)

                                    Spacer()

                                    TextField("e.g., Coffee, Chicken Salad", text: $mealName)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 150)
                                }
                            }
                        }
                    }
                    
                    // Meal Type Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Meal Type")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        GlassCard {
                            VStack(spacing: 12) {
                                ForEach(MealType.allCases, id: \.self) { mealType in
                                    HStack {
                                        Image(systemName: mealType.icon)
                                            .font(.title2)
                                            .foregroundStyle(selectedMealType == mealType ? .blue : .secondary)
                                            .frame(width: 24, height: 24)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(mealType.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedMealType == mealType {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                                .font(.title2)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedMealType = mealType
                                    }
                                    
                                    if mealType != MealType.allCases.last {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Save Meal Toggle Section
                    if !isEditing && !mealName.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            GlassCard {
                                Toggle(isOn: $saveMeal) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "bookmark.fill")
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                            .frame(width: 24, height: 24)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Save for later")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text("Quick add '\(mealName)' in the future")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Delete Button for Editing
                    if isEditing {
                        GlassCard {
                            Button("Delete Entry") {
                                deleteEntry()
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding()
            }
            .background(
                ZStack {
                    // Navy blue base
                    Color(red: 0.04, green: 0.08, blue: 0.15)
                        .ignoresSafeArea()
                    
                    // Subtle gradient overlays for depth
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.03),
                            Color.clear,
                            Color.red.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            )
            .navigationTitle(isEditing ? "Edit Food Entry" : "Add Food Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    GlassButton(
                        isEditing ? "Update" : "Add",
                        icon: isEditing ? "checkmark.circle.fill" : "plus.circle.fill",
                        isLoading: isLoading,
                        style: .blue
                    ) {
                        saveEntry()
                    }
                    .disabled(calories.isEmpty || isLoading)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK") { }
            } message: {
                Text(validationErrorMessage)
            }
            .disabled(isLoading)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnitSystemChanged"))) { notification in
                if let unitSystem = notification.object as? UnitSystem {
                    currentUnitSystem = unitSystem
                }
            }
        }
    }
    
    private func saveEntry() {
        guard validateInput() else { return }
        
        isLoading = true
        
        Task {
            do {
                let caloriesValue = Double(calories) ?? 0
                let proteinValue = protein.isEmpty ? nil : Double(protein)
                let carbsValue = carbs.isEmpty ? nil : Double(carbs)
                let fatsValue = fats.isEmpty ? nil : Double(fats)
                let saturatedFatsValue = saturatedFats.isEmpty ? nil : Double(saturatedFats)
                let trimmedMealName = mealName.trimmingCharacters(in: .whitespacesAndNewlines)

                let entry: FoodEntry
                if let existingEntry = existingEntry {
                    // Update existing entry
                    entry = FoodEntry(
                        id: existingEntry.id,
                        calories: caloriesValue,
                        protein: proteinValue,
                        carbs: carbsValue,
                        fats: fatsValue,
                        saturatedFats: saturatedFatsValue,
                        timestamp: existingEntry.timestamp,
                        mealType: selectedMealType,
                        notes: trimmedMealName.isEmpty ? nil : trimmedMealName
                    )
                    await nutritionViewModel.updateFoodEntry(entry)
                } else {
                    // Create new entry
                    entry = FoodEntry(
                        calories: caloriesValue,
                        protein: proteinValue,
                        carbs: carbsValue,
                        fats: fatsValue,
                        saturatedFats: saturatedFatsValue,
                        mealType: selectedMealType,
                        notes: trimmedMealName.isEmpty ? nil : trimmedMealName
                    )
                    await nutritionViewModel.addFoodEntry(entry)
                }

                // Cache the meal only if user wants to save it and it has a name
                if saveMeal && !trimmedMealName.isEmpty {
                    mealCacheService.addMeal(name: trimmedMealName, calories: caloriesValue, protein: proteinValue)
                }

                await MainActor.run {
                    isLoading = false
                    // Show a brief success message before dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    validationErrorMessage = error.localizedDescription
                    showingValidationError = true
                }
            }
        }
    }

    // MARK: - Quick Meal Selection Section

    private var quickMealSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved Meals")
                .font(.headline)
                .fontWeight(.semibold)

            GlassCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search saved meals...", text: $searchText)

                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 8)

                    let filteredMeals = searchText.isEmpty ? 
                        Array(mealCacheService.cachedMeals.prefix(5)) : 
                        mealCacheService.searchMeals(query: searchText)
                    
                    if !filteredMeals.isEmpty {
                        Divider()
                        
                        LazyVStack(spacing: 8) {
                            ForEach(filteredMeals.prefix(5), id: \.id) { meal in
                                mealSelectionRow(meal)
                            }
                        }
                    } else if !searchText.isEmpty {
                        Divider()
                        Text("No matching meals found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        Divider()
                        Text("No saved meals yet. Add a meal name and enable 'Save for later' to quick add meals in the future.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }

    private func mealSelectionRow(_ meal: CachedMeal) -> some View {
        Button {
            selectMeal(meal)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    HStack {
                        Text("\(Int(meal.calories)) kcal")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        if let protein = meal.protein {
                            Text("\(String(format: "%.1f", protein))g protein")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title2)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func selectMeal(_ meal: CachedMeal) {
        let updatedMeal = mealCacheService.useMeal(meal)

        calories = String(format: "%.0f", updatedMeal.calories)
        if let proteinValue = updatedMeal.protein {
            protein = String(format: "%.1f", proteinValue)
        } else {
            protein = ""
        }
        // Note: CachedMeal doesn't have carbs and fats yet, so leave them empty
        carbs = ""
        fats = ""
        mealName = updatedMeal.name
        saveMeal = true  // Automatically enable save for meals from cache

        searchText = ""
    }

    private func deleteEntry() {
        guard let existingEntry = existingEntry else { return }
        
        isLoading = true
        
        Task {
            await nutritionViewModel.deleteFoodEntry(existingEntry)
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
    
    private func validateInput() -> Bool {
        // Validate calories
        guard let caloriesValue = Double(calories), caloriesValue > 0, caloriesValue <= 10000 else {
            validationErrorMessage = "Calories must be between 1 and 10,000"
            showingValidationError = true
            return false
        }
        
        // Validate protein if provided
        if !protein.isEmpty {
            guard let proteinValue = Double(protein), proteinValue >= 0, proteinValue <= 1000 else {
                validationErrorMessage = "Protein must be between 0 and 1,000 grams"
                showingValidationError = true
                return false
            }
        }

        // Validate carbs if provided
        if !carbs.isEmpty {
            guard let carbsValue = Double(carbs), carbsValue >= 0, carbsValue <= 1000 else {
                validationErrorMessage = "Carbs must be between 0 and 1,000 grams"
                showingValidationError = true
                return false
            }
        }

        // Validate fats if provided
        if !fats.isEmpty {
            guard let fatsValue = Double(fats), fatsValue >= 0, fatsValue <= 500 else {
                validationErrorMessage = "Fats must be between 0 and 500 grams"
                showingValidationError = true
                return false
            }
            
            // Validate saturated fats if provided
            if !saturatedFats.isEmpty {
                guard let saturatedFatsValue = Double(saturatedFats), saturatedFatsValue >= 0, saturatedFatsValue <= 500 else {
                    validationErrorMessage = "Saturated fats must be between 0 and 500 grams"
                    showingValidationError = true
                    return false
                }
                
                // Saturated fats cannot exceed total fats
                if saturatedFatsValue > fatsValue {
                    validationErrorMessage = "Saturated fats cannot exceed total fats"
                    showingValidationError = true
                    return false
                }
            }
        } else if !saturatedFats.isEmpty {
            // If saturated fats is provided but fats is not
            validationErrorMessage = "Please enter total fats before adding saturated fats"
            showingValidationError = true
            return false
        }

        // Validate meal name length
        if mealName.count > 100 {
            validationErrorMessage = "Meal name cannot exceed 100 characters"
            showingValidationError = true
            return false
        }

        return true
    }
}

// MARK: - Preview

struct FoodEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let mockDataService = MockDataService()
        let mockCalculationService = MockCalculationService()
        let mockHealthKitService = MockHealthKitService()
        let nutritionViewModel = NutritionViewModel(
            dataService: mockDataService,
            calculationService: mockCalculationService,
            healthKitService: mockHealthKitService
        )
        
        Group {
            // New entry
            FoodEntryView(nutritionViewModel: nutritionViewModel)
                .previewDisplayName("New Entry")
            
            // Editing entry
            FoodEntryView(
                nutritionViewModel: nutritionViewModel,
                existingEntry: FoodEntry(
                    calories: 350,
                    protein: 25,
                    carbs: 15,
                    fats: 20,
                    saturatedFats: 5,
                    mealType: .lunch,
                    notes: "Chicken salad"
                )
            )
            .previewDisplayName("Edit Entry")
        }
    }
}

// MARK: - Mock Services for Preview


class MockDataService: DataServiceProtocol {
    func saveUser(_ user: User) async throws { }
    func fetchUser() async throws -> User? { return nil }
    func createUserFromHealthKit(healthKitService: HealthKitServiceProtocol) async throws -> User {
        return User(weight: 70.0)
    }
    func resetAllData() async throws { }
    func saveFoodEntry(_ entry: FoodEntry, for user: User) async throws { }
    func saveFoodEntry(_ entry: FoodEntry) async throws { }
    func updateFoodEntry(_ entry: FoodEntry) async throws { }
    func deleteFoodEntry(_ entry: FoodEntry) async throws { }
    func fetchFoodEntries(for date: Date, user: User) async throws -> [FoodEntry] { return [] }
    func deleteFoodEntry(withId id: UUID) async throws { }
    func saveDailyNutrition(_ nutrition: DailyNutrition) async throws { }
    func fetchDailyNutrition(for date: Date) async throws -> DailyNutrition? { return nil }
    func saveDailyStats(_ stats: DailyStats, for user: User) async throws { }
    func saveDailyStats(_ stats: DailyStats) async throws { }
    func fetchDailyStats(for dateRange: ClosedRange<Date>, user: User) async throws -> [DailyStats] { return [] }
    func fetchDailyStats(for date: Date) async throws -> DailyStats? { return nil }
    func saveGoal(_ goal: FitnessGoal, for user: User) async throws { }
    func updateGoal(_ goal: FitnessGoal) async throws { }
    func deleteGoal(_ goal: FitnessGoal) async throws { }
    func fetchActiveGoal(for user: User) async throws -> FitnessGoal? { return nil }
    func fetchActiveGoal() async throws -> FitnessGoal? { return nil }
    func fetchAllGoals(for user: User) async throws -> [FitnessGoal] { return [] }
}

class MockCalculationService: CalculationServiceProtocol {
    func calculateBMR(age: Int, weight: Double, height: Double, gender: Gender) -> Double { return 1500 }
    func calculateDailyCalorieNeeds(bmr: Double, activityLevel: ActivityLevel) -> Double { return 2000 }
    func calculateMaintenanceCalories(bmr: Double, activityLevel: ActivityLevel) -> Double { return 2000 }
    func calculateCalorieTargetForGoal(dailyCalorieNeeds: Double, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double { return 1800 }
    func calculateCalorieTarget(bmr: Double, activityLevel: ActivityLevel, goalType: GoalType, weeklyWeightChangeGoal: Double) -> Double { return 1800 }
    func calculateProteinTarget(weight: Double, goalType: GoalType) -> Double { return 100 }
    func calculateProteinGoal(for user: User?) -> Double { return 100 }
    func calculateCarbGoal(for user: User?) -> Double { return 200 }
    func calculateFatGoal(for user: User?) -> Double { return 65 }
    func calculateWeightLossCalories(maintenanceCalories: Double, weeklyWeightLoss: Double) -> Double { return 1500 }
    func calculateWeightGainCalories(maintenanceCalories: Double, weeklyWeightGain: Double) -> Double { return 2200 }
    func validateUserData(age: Int, weight: Double, height: Double) throws { }
}


