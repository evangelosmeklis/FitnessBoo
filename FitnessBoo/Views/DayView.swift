//
//  DayView.swift
//  FitnessBoo
//
//  Created by Claude on 3/10/25.
//

import SwiftUI

struct DayView: View {
    @StateObject private var nutritionViewModel: NutritionViewModel
    private let healthKitService: HealthKitServiceProtocol
    @State private var editingEntry: FoodEntry?
    @State private var showingEditSheet = false
    @State private var currentUnitSystem: UnitSystem = .metric

    init(dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(
            dataService: dataService,
            calculationService: calculationService,
            healthKitService: healthKitService
        ))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Summary Cards
                    summarySection

                    // Today's Food Entries
                    foodEntriesSection

                    // Water Intake
                    waterSection
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadTodaysData()
                loadUnitSystem()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnitSystemChanged"))) { notification in
                if let unitSystem = notification.object as? UnitSystem {
                    currentUnitSystem = unitSystem
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let entry = editingEntry {
                    EditFoodEntrySheet(
                        entry: entry,
                        onSave: { updatedEntry in
                            Task {
                                await nutritionViewModel.updateFoodEntry(updatedEntry)
                                showingEditSheet = false
                                editingEntry = nil
                            }
                        },
                        onCancel: {
                            showingEditSheet = false
                            editingEntry = nil
                        }
                    )
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Pure black base
            Color.black
                .ignoresSafeArea()
            
            // Futuristic gradient overlays
            LinearGradient(
                colors: [
                    Color.green.opacity(0.05),
                    Color.clear,
                    Color.cyan.opacity(0.04),
                    Color.clear,
                    Color.blue.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    Text(Date().formatted(.dateTime.month(.wide).day()))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Quick stats badge
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                    Text("\(todaysFoodEntries.count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(12)
            }

            // Large calorie cards
            HStack(spacing: 12) {
                // Calories consumed
                ZStack {
                    // Outer glow
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.cyan.opacity(0.1))
                        .blur(radius: 15)
                    
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.cyan.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(.cyan)
                                        .font(.title3)
                                }
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CALORIES")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .tracking(1)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(nutritionViewModel.totalCalories))")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(.cyan)
                                    
                                    Text("kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("of \(Int(nutritionViewModel.dailyNutrition?.calorieTarget ?? 0))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                // Protein consumed
                ZStack {
                    // Outer glow
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.green.opacity(0.1))
                        .blur(radius: 15)
                    
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "leaf.fill")
                                        .foregroundStyle(.green)
                                        .font(.title3)
                                }
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PROTEIN")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .tracking(1)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(nutritionViewModel.totalProtein))")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(.green)
                                    
                                    Text("g")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("of \(Int(nutritionViewModel.dailyNutrition?.proteinTarget ?? 0))g")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Food Entries Section

    private var foodEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MEALS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    Text("Today's Food")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()
            }

            if todaysFoodEntries.isEmpty {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "fork.knife")
                                .font(.system(size: 24))
                                .foregroundStyle(.orange)
                        }

                        VStack(spacing: 8) {
                            Text("No meals logged yet")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Text("Add your first meal from the Dashboard tab")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(todaysFoodEntries) { entry in
                        EnhancedFoodRow(
                            entry: entry,
                            onEdit: {
                                editingEntry = entry
                                showingEditSheet = true
                            },
                            onDelete: {
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

    // MARK: - Water Section

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HYDRATION")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    Text("Water Intake")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()
            }

            GlassCard(cornerRadius: 20) {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            // Water amount
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", nutritionViewModel.totalWater / 1000))
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.cyan)
                                
                                Text("L")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }

                            // Goal progress
                            VStack(alignment: .leading, spacing: 6) {
                                Text("GOAL: \(String(format: "%.1fL", nutritionViewModel.dailyWaterTarget / 1000))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)
                                
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.cyan.opacity(0.15))
                                            .frame(height: 8)
                                        
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.cyan, Color.blue],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * min(nutritionViewModel.waterProgress, 1.0), height: 8)
                                            .shadow(color: Color.cyan.opacity(0.5), radius: 4, x: 0, y: 0)
                                    }
                                }
                                .frame(height: 8)
                                
                                Text("\(Int(nutritionViewModel.waterProgress * 100))% complete")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        // Circular progress indicator
                        ZStack {
                            // Background ring
                            Circle()
                                .stroke(Color.cyan.opacity(0.15), lineWidth: 16)
                                .frame(width: 110, height: 110)

                            // Progress ring with glow
                            Circle()
                                .trim(from: 0, to: min(nutritionViewModel.waterProgress, 1.0))
                                .stroke(
                                    Color.cyan,
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                )
                                .frame(width: 110, height: 110)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: Color.cyan.opacity(0.5), radius: 10, x: 0, y: 0)
                                .animation(.easeInOut(duration: 0.8), value: nutritionViewModel.waterProgress)

                            // Center icon
                            Image(systemName: "drop.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.cyan)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var todaysFoodEntries: [FoodEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return nutritionViewModel.foodEntries.filter { entry in
            calendar.isDate(entry.timestamp, inSameDayAs: today)
        }
    }

    // MARK: - Helper Methods

    private func loadTodaysData() async {
        await nutritionViewModel.loadDailyNutrition(for: Date())
    }

    private func loadUnitSystem() {
        if let savedUnit = UserDefaults.standard.string(forKey: "UnitSystem"),
           let unitSystem = UnitSystem(rawValue: savedUnit) {
            currentUnitSystem = unitSystem
        }
    }
}

// MARK: - Supporting Views

struct EnhancedFoodRow: View {
    let entry: FoodEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 16) {
                // Top row: Meal name and time
                HStack(alignment: .top, spacing: 12) {
                    // Meal type icon
                    if let mealType = entry.mealType {
                        ZStack {
                            Circle()
                                .fill(mealColor(for: mealType).opacity(colorScheme == .dark ? 0.2 : 0.15))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: mealType.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(mealColor(for: mealType))
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    // Meal name and type
                    VStack(alignment: .leading, spacing: 6) {
                        // Prominent meal name
                        if let notes = entry.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        } else {
                            Text("Unnamed Meal")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Meal type badge and time
                        HStack(spacing: 8) {
                            if let mealType = entry.mealType {
                                Text(mealType.displayName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(mealColor(for: mealType))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(mealColor(for: mealType).opacity(0.15))
                                    .cornerRadius(8)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(entry.timestamp.formatted(.dateTime.hour().minute()))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Nutrition info row
                HStack(spacing: 20) {
                    // Calories
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("CALORIES")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(entry.calories))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Text("kcal")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Protein
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "leaf.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("PROTEIN")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            if let protein = entry.protein, protein > 0 {
                                Text("\(Int(protein))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                Text("g")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("—")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                
                // Action buttons row
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Edit")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Delete")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mealColor(for type: MealType) -> Color {
        switch type {
        case .breakfast: return Color(red: 0.0, green: 0.9, blue: 0.7) // Turquoise
        case .lunch: return colorScheme == .dark ? Color.neonGreen : .green
        case .dinner: return .cyan
        case .snack: return Color(red: 0.4, green: 0.7, blue: 1.0) // Sky blue
        }
    }
}

struct EditFoodEntrySheet: View {
    let entry: FoodEntry
    let onSave: (FoodEntry) -> Void
    let onCancel: () -> Void

    @State private var calories: String
    @State private var protein: String
    @State private var notes: String
    @State private var selectedMealType: MealType?

    init(entry: FoodEntry, onSave: @escaping (FoodEntry) -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onCancel = onCancel

        _calories = State(initialValue: String(Int(entry.calories)))
        _protein = State(initialValue: entry.protein != nil ? String(Int(entry.protein!)) : "")
        _notes = State(initialValue: entry.notes ?? "")
        _selectedMealType = State(initialValue: entry.mealType)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Nutrition") {
                    HStack {
                        Label("Calories", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        TextField("Calories", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Label("Protein", systemImage: "leaf.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        TextField("Protein (g)", text: $protein)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section("Details") {
                    TextField("Notes (optional)", text: $notes)

                    Picker("Meal Type", selection: $selectedMealType) {
                        Text("None").tag(nil as MealType?)
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type as MealType?)
                        }
                    }
                }
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard let caloriesValue = Double(calories), caloriesValue > 0 else {
            return false
        }

        if !protein.isEmpty {
            guard let proteinValue = Double(protein), proteinValue >= 0 else {
                return false
            }
        }

        return true
    }

    private func saveChanges() {
        guard let caloriesValue = Double(calories) else { return }

        let proteinValue = protein.isEmpty ? nil : Double(protein)

        let updatedEntry = FoodEntry(
            id: entry.id,
            calories: caloriesValue,
            protein: proteinValue,
            timestamp: entry.timestamp,
            mealType: selectedMealType,
            notes: notes.isEmpty ? nil : notes
        )

        onSave(updatedEntry)
    }
}

// MARK: - Preview

struct DayView_Previews: PreviewProvider {
    static var previews: some View {
        DayView(
            dataService: DataService.shared,
            calculationService: CalculationService(),
            healthKitService: HealthKitService()
        )
    }
}
