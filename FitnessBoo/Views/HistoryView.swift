//
//  HistoryView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    
    init(dataService: DataServiceProtocol) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(dataService: dataService))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Calendar view
                CalendarView(
                    selectedDate: $viewModel.selectedDate,
                    datesWithEntries: viewModel.datesWithEntries
                )
                .padding(.horizontal)
                
                // Weekly summary
                weeklySummarySection
                
                // Daily summary
                dailySummarySection
                
                // Food entries for selected date
                foodEntriesList
            }
            .navigationTitle("History")
            .onAppear {
                viewModel.loadDatesWithEntries()
            }
        }
    }
    
    private var weeklySummarySection: some View {
        VStack(alignment: .leading) {
            Text("Weekly Summary")
                .font(.headline)
                .padding(.horizontal)
            
            if let weeklyBalance = viewModel.weeklyBalance {
                HStack {
                    Text("Total Balance:")
                    Spacer()
                    Text(weeklyBalance > 0 ? "+\(Int(weeklyBalance)) kcal" : "\(Int(weeklyBalance)) kcal")
                        .foregroundColor(weeklyBalance > 0 ? .orange : .green)
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var dailySummarySection: some View {
        if let dailyNutrition = viewModel.dailyNutrition {
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily Summary")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(spacing: 12) {
                    // Caloric Deficit/Surplus
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Caloric Balance")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            let deficit = dailyNutrition.calorieTarget - dailyNutrition.totalCalories
                            HStack {
                                Text(deficit > 0 ? "Deficit:" : "Surplus:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("\(Int(abs(deficit))) kcal")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(deficit > 0 ? .green : .orange)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(dailyNutrition.totalCalories)) / \(Int(dailyNutrition.calorieTarget))")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("kcal consumed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Protein Progress
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Protein Progress")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                Text("\(String(format: "%.1f", dailyNutrition.totalProtein))g")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)

                                Text("/ \(String(format: "%.0f", dailyNutrition.proteinTarget))g")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Protein progress bar
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(dailyNutrition.proteinProgress * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(dailyNutrition.isProteinTargetMet ? .green : .secondary)

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.green)
                                    .frame(width: 60 * min(1.0, dailyNutrition.proteinProgress), height: 4)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var foodEntriesList: some View {
        if viewModel.isLoading {
            SwiftUI.ProgressView("Loading entries...")
        } else if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
        } else if viewModel.foodEntries.isEmpty {
            Text("No entries for this date.")
                .foregroundColor(.secondary)
                .padding()
        } else {
            List {
                ForEach(viewModel.foodEntries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.mealType?.displayName ?? "Snack")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                if let notes = entry.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Int(entry.calories)) kcal")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)

                                if let protein = entry.protein {
                                    Text("\(String(format: "%.1f", protein))g protein")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
        }
    }
}

// MARK: - Preview

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(dataService: DataService.shared)
    }
}
