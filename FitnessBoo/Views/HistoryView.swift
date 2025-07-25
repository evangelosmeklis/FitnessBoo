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
            VStack(alignment: .leading) {
                Text("Daily Summary")
                    .font(.headline)
                
                HStack {
                    Text("Caloric Balance:")
                    Spacer()
                    Text("\(Int(dailyNutrition.netCalories)) kcal")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
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
                    VStack(alignment: .leading) {
                        HStack {
                            Text(entry.mealType?.displayName ?? "Snack")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(entry.calories)) kcal")
                        }
                        if let notes = entry.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(dataService: MockDataService())
    }
}
