//
//  FoodEntryView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI

struct FoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var nutritionViewModel: NutritionViewModel
    
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var selectedMealType: MealType = .snack
    @State private var notes: String = ""
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    @State private var isLoading = false
    
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
            _selectedMealType = State(initialValue: entry.mealType ?? MealType.suggestedMealType())
            _notes = State(initialValue: entry.notes ?? "")
        } else {
            _selectedMealType = State(initialValue: MealType.suggestedMealType())
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Details")) {
                    // Calories input
                    HStack {
                        Label("Calories", systemImage: "flame.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("0", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    
                    // Protein input (optional)
                    HStack {
                        Label("Protein (g)", systemImage: "leaf.fill")
                            .foregroundColor(.green)
                        Spacer()
                        TextField("Optional", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                }
                
                Section(header: Text("Meal Type")) {
                    Picker("Meal Type", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            HStack {
                                Image(systemName: mealType.icon)
                                Text(mealType.displayName)
                            }
                            .tag(mealType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextField("Add notes about this food...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if isEditing {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            deleteEntry()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Food Entry" : "Add Food Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Add") {
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
        }
    }
    
    private func saveEntry() {
        guard validateInput() else { return }
        
        isLoading = true
        
        Task {
            do {
                let caloriesValue = Double(calories) ?? 0
                let proteinValue = protein.isEmpty ? nil : Double(protein)
                
                let entry: FoodEntry
                if let existingEntry = existingEntry {
                    // Update existing entry
                    entry = FoodEntry(
                        id: existingEntry.id,
                        calories: caloriesValue,
                        protein: proteinValue,
                        timestamp: existingEntry.timestamp,
                        mealType: selectedMealType,
                        notes: notes.isEmpty ? nil : notes
                    )
                    await nutritionViewModel.updateFoodEntry(entry)
                } else {
                    // Create new entry
                    entry = FoodEntry(
                        calories: caloriesValue,
                        protein: proteinValue,
                        mealType: selectedMealType,
                        notes: notes.isEmpty ? nil : notes
                    )
                    await nutritionViewModel.addFoodEntry(entry)
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
        
        // Validate notes length
        if notes.count > 500 {
            validationErrorMessage = "Notes cannot exceed 500 characters"
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
        let nutritionViewModel = NutritionViewModel(
            dataService: mockDataService,
            calculationService: mockCalculationService
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
