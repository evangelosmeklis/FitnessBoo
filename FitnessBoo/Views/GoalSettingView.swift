//
//  GoalSettingView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI

struct GoalSettingView: View {
    @StateObject private var viewModel: GoalViewModel
    @State private var user: User?
    @State private var showingDatePicker = false
    @Environment(\.dismiss) private var dismiss
    
    init(calculationService: CalculationServiceProtocol = CalculationService(), 
         dataService: DataServiceProtocol = DataService.shared) {
        self._viewModel = StateObject(wrappedValue: GoalViewModel(
            calculationService: calculationService,
            dataService: dataService
        ))
    }
    
    var body: some View {
        NavigationView {
            Form {
                goalTypeSection
                
                if viewModel.selectedGoalType != .maintainWeight {
                    targetWeightSection
                    targetDateSection
                }
                
                weeklyChangeSection
                estimatedTargetsSection
                
                if !viewModel.errorMessage.isNilOrEmpty {
                    errorSection
                }
            }
            .navigationTitle("Set Your Goal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            if let user = user {
                                if viewModel.currentGoal != nil {
                                    await viewModel.updateGoal(for: user)
                                } else {
                                    await viewModel.createGoal(for: user)
                                }
                                
                                if !viewModel.showingError {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(!viewModel.validateCurrentGoal() || viewModel.isLoading)
                }
            }
            .task {
                await loadUserAndGoal()
            }
            .alert("Goal Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - View Sections
    
    private var goalTypeSection: some View {
        Section {
            ForEach(GoalType.allCases, id: \.self) { goalType in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goalType.displayName)
                            .font(.headline)
                        Text(goalType.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.selectedGoalType == goalType {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedGoalType = goalType
                    updateWeightChangeForGoalType(goalType)
                }
            }
        } header: {
            Text("Goal Type")
        }
    }
    
    private var targetWeightSection: some View {
        Section {
            HStack {
                Text("Target Weight")
                Spacer()
                TextField("Enter weight", text: $viewModel.targetWeight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("kg")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Target")
        } footer: {
            if let user = user, !viewModel.targetWeight.isEmpty,
               let targetWeight = Double(viewModel.targetWeight) {
                let difference = abs(targetWeight - user.weight)
                let direction = targetWeight > user.weight ? "gain" : "lose"
                Text("You need to \(direction) \(difference, specifier: "%.1f") kg")
                    .font(.caption)
            }
        }
    }
    
    private var targetDateSection: some View {
        Section {
            HStack {
                Text("Target Date")
                Spacer()
                Button(action: { showingDatePicker.toggle() }) {
                    Text(viewModel.targetDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    DatePicker(
                        "Target Date",
                        selection: $viewModel.targetDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .navigationTitle("Target Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        } footer: {
            if !viewModel.estimatedTimeToGoal.isEmpty && viewModel.estimatedTimeToGoal != "N/A" {
                Text("Estimated time to goal: \(viewModel.estimatedTimeToGoal)")
                    .font(.caption)
            }
        }
    }
    
    private var weeklyChangeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Weekly Change")
                    Spacer()
                    Text(viewModel.formatWeightChange(viewModel.weeklyWeightChangeGoal))
                        .foregroundColor(.secondary)
                }
                
                let range = viewModel.getRecommendedWeightChangeRange()
                Slider(
                    value: $viewModel.weeklyWeightChangeGoal,
                    in: range,
                    step: 0.1
                ) {
                    Text("Weekly Change")
                } minimumValueLabel: {
                    Text("\(range.lowerBound, specifier: "%.1f")")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("\(range.upperBound, specifier: "%.1f")")
                        .font(.caption)
                }
            }
        } header: {
            Text("Rate of Change")
        } footer: {
            Text(getWeeklyChangeFooterText())
                .font(.caption)
        }
    }
    
    private var estimatedTargetsSection: some View {
        Section {
            HStack {
                Text("Daily Calories")
                Spacer()
                Text("\(Int(viewModel.estimatedDailyCalories)) cal")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Daily Protein")
                Spacer()
                Text("\(Int(viewModel.estimatedDailyProtein)) g")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Estimated Daily Targets")
        } footer: {
            Text("These targets are calculated based on your profile and selected goal.")
                .font(.caption)
        }
    }
    
    private var errorSection: some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(viewModel.errorMessage ?? "")
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserAndGoal() async {
        do {
            user = try await DataService.shared.fetchUser()
            if let user = user {
                await viewModel.loadCurrentGoal(for: user)
            }
        } catch {
            viewModel.errorMessage = "Failed to load user data"
            viewModel.showingError = true
        }
    }
    
    private func updateWeightChangeForGoalType(_ goalType: GoalType) {
        let range = goalType.recommendedWeightChangeRange
        let midpoint = (range.lowerBound + range.upperBound) / 2
        viewModel.weeklyWeightChangeGoal = midpoint
    }
    
    private func getWeeklyChangeFooterText() -> String {
        switch viewModel.selectedGoalType {
        case .loseWeight:
            return "Safe weight loss is 0.25-1.0 kg per week. Faster loss may lead to muscle loss."
        case .gainWeight:
            return "Healthy weight gain is 0.25-0.5 kg per week. Faster gain may increase fat storage."
        case .gainMuscle:
            return "Quality muscle gain is 0.1-0.3 kg per week with proper training and nutrition."
        case .maintainWeight:
            return "Maintenance allows for small fluctuations around your current weight."
        }
    }
}

// MARK: - Extensions

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

// MARK: - Preview

struct GoalSettingView_Previews: PreviewProvider {
    static var previews: some View {
        GoalSettingView()
    }
}