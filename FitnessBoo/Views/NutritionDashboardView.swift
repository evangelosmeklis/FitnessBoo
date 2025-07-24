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
                // Calories Progress
                ProgressCard(
                    title: "Calories",
                    current: nutritionViewModel.totalCalories,
                    target: nutritionViewModel.dailyNutrition?.calorieTarget ?? 0,
                    remaining: nutritionViewModel.remainingCalories,
                    progress: nutritionViewModel.calorieProgress,
                    color: .orange,
                    icon: "flame.fill",
                    unit: "cal"
                )
                
                // Protein Progress
                ProgressCard(
                    title: "Protein",
                    current: nutritionViewModel.totalProtein,
                    target: nutritionViewModel.dailyNutrition?.proteinTarget ?? 0,
                    remaining: nutritionViewModel.remainingProtein,
                    progress: nutritionViewModel.proteinProgress,
                    color: .green,
                    icon: "leaf.fill",
                    unit: "g"
                )
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
            
            HStack(spacing: 12) {
                WaterButton(amount: 250) {
                    Task { await nutritionViewModel.addWater(milliliters: 250) }
                }
                WaterButton(amount: 500) {
                    Task { await nutritionViewModel.addWater(milliliters: 500) }
                }
                WaterButton(amount: 750) {
                    Task { await nutritionViewModel.addWater(milliliters: 750) }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
            
            ProgressView(value: min(progress, 1.0))
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
    
    private var totalProtein: Double {
        entries.reduce(0) { $0 + ($1.protein ?? 0) }
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
                    if totalProtein > 0 {
                        Text("\(String(format: "%.1f", totalProtein))g protein")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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
                        
                        if let protein = entry.protein, protein > 0 {
                            Text("• \(String(format: "%.1f", protein))g protein")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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