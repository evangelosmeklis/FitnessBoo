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
    @State private var hasChanges = false
    @State private var showSuccessMessage = false
    @FocusState private var isTargetWeightFocused: Bool
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
                                    // Notify other views that goal was updated
                                    NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
                                    
                                    // Show success message
                                    showSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        showSuccessMessage = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                    .disabled(!viewModel.validateCurrentGoal() || viewModel.isLoading || !hasValidInput())
                }
            }
            .task {
                await loadUserAndGoal()
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                isTargetWeightFocused = false
            }
            .onChange(of: viewModel.selectedGoalType) { _ in
                checkForChanges()
            }
            .onChange(of: viewModel.targetWeight) { _ in
                checkForChanges()
            }
            .onChange(of: viewModel.targetDate) { _ in
                checkForChanges()
            }
            .onChange(of: viewModel.weeklyWeightChangeGoal) { _ in
                checkForChanges()
            }
            .alert("Goal Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .overlay(
                Group {
                    if showSuccessMessage {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Goal saved successfully!")
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding(.bottom, 50)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: showSuccessMessage)
                    }
                }
            )
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
                    // Use withAnimation for smooth transitions
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedGoalType = goalType
                    }
                    
                    // Update weight change range
                    updateWeightChangeForGoalType(goalType)
                    
                    // Clear target weight for maintain weight goal
                    if goalType == .maintainWeight {
                        viewModel.targetWeight = ""
                        viewModel.errorMessage = nil
                    }
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
                    .focused($isTargetWeightFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isTargetWeightFocused = false
                                validateTargetWeight()
                            }
                        }
                    }
                    .onChange(of: viewModel.targetWeight) { _ in
                        validateTargetWeight()
                    }
                Text("kg")
                    .foregroundColor(.secondary)
            }
            
            // Show validation error if any
            if let validationError = getTargetWeightValidationError() {
                Text(validationError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Text("Target")
        } footer: {
            if let user = user, !viewModel.targetWeight.isEmpty,
               let targetWeight = Double(viewModel.targetWeight),
               getTargetWeightValidationError() == nil {
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
                // Initialize hasChanges after loading
                checkForChanges()
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
    
    private func checkForChanges() {
        guard let currentGoal = viewModel.currentGoal else {
            // If no current goal exists, require meaningful input for changes
            let hasTargetWeight = !viewModel.targetWeight.isEmpty && 
                                 Double(viewModel.targetWeight) != nil && 
                                 Double(viewModel.targetWeight)! > 0
            let hasNonDefaultGoalType = viewModel.selectedGoalType != .loseWeight
            let hasNonDefaultWeeklyChange = abs(viewModel.weeklyWeightChangeGoal - (-0.5)) > 0.01
            
            // For goals that require target weight, ensure it's provided
            if viewModel.selectedGoalType != .maintainWeight {
                hasChanges = hasTargetWeight && (hasNonDefaultGoalType || hasNonDefaultWeeklyChange || hasTargetWeight)
            } else {
                hasChanges = hasNonDefaultGoalType || hasNonDefaultWeeklyChange
            }
            return
        }
        
        // Compare current values with existing goal
        let targetWeightChanged = (currentGoal.targetWeight?.formatted() ?? "") != viewModel.targetWeight
        let goalTypeChanged = currentGoal.type != viewModel.selectedGoalType
        let weeklyChangeChanged = abs(currentGoal.weeklyWeightChangeGoal - viewModel.weeklyWeightChangeGoal) > 0.01
        let targetDateChanged = currentGoal.targetDate != viewModel.targetDate
        
        hasChanges = targetWeightChanged || goalTypeChanged || weeklyChangeChanged || targetDateChanged
    }
    
    private func hasValidInput() -> Bool {
        // Basic validation
        guard viewModel.validateCurrentGoal() else {
            return false
        }
        
        // Target weight validation for non-maintain goals
        if viewModel.selectedGoalType != .maintainWeight {
            guard let user = user else { return false }
            let validation = viewModel.validateTargetWeight(currentWeight: user.weight)
            return validation.isValid
        }
        
        return true
    }
    
    private func validateTargetWeight() {
        guard let user = user else { return }
        let validation = viewModel.validateTargetWeight(currentWeight: user.weight)
        
        if !validation.isValid {
            viewModel.errorMessage = validation.errorMessage
        } else {
            // Clear error if validation passes
            if viewModel.errorMessage?.contains("Target weight") == true {
                viewModel.errorMessage = nil
            }
        }
    }
    
    private func getTargetWeightValidationError() -> String? {
        guard let user = user else { return nil }
        let validation = viewModel.validateTargetWeight(currentWeight: user.weight)
        return validation.isValid ? nil : validation.errorMessage
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