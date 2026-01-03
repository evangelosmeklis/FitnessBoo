//
//  GoalSettingView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI
import Combine
import HealthKit

struct GoalSettingView: View {
    @StateObject private var viewModel: GoalViewModel
    @State private var user: User?
    @State private var currentUnitSystem: UnitSystem = .metric
    @State private var showingDatePicker = false
    @State private var hasChanges = false
    @State private var showSuccessMessage = false
    @FocusState private var isTargetWeightFocused: Bool
    @FocusState private var isCurrentWeightFocused: Bool
    @FocusState private var isWaterTargetFocused: Bool
    @FocusState private var isProteinTargetFocused: Bool
    @FocusState private var isCarbsTargetFocused: Bool
    @FocusState private var isFatsTargetFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    // Debounced weight update
    @State private var weightUpdateTask: Task<Void, Never>?
    
    init(calculationService: CalculationServiceProtocol = CalculationService(), 
         dataService: DataServiceProtocol = DataService.shared,
         healthKitService: HealthKitServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: GoalViewModel(
            calculationService: calculationService,
            dataService: dataService,
            healthKitService: healthKitService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    goalTypeSection

                    currentWeightSection

                    targetWeightSection

                    if viewModel.calculatedGoalType != .maintainWeight {
                        targetDateSection
                    }

                    dailyWaterTargetSection

                    dailyProteinTargetSection

                    dailyCarbsTargetSection

                    dailyFatsTargetSection

                    dailyCalorieAdjustmentSection

                    if !viewModel.errorMessage.isNilOrEmpty {
                        errorSection
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationTitle("Set Your Goal")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadUserAndGoal()
                loadUnitSystem()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnitSystemChanged"))) { notification in
                if let unitSystem = notification.object as? UnitSystem {
                    currentUnitSystem = unitSystem
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                isTargetWeightFocused = false
                isCurrentWeightFocused = false
                isWaterTargetFocused = false
                isProteinTargetFocused = false
                isCarbsTargetFocused = false
                isFatsTargetFocused = false
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        handleKeyboardDone()
                    }
                }
            }
            .onChange(of: viewModel.selectedGoalType) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.targetWeight) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.targetDate) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.weeklyWeightChangeGoal) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.dailyWaterTarget) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.dailyProteinTarget) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.dailyCarbsTarget) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.dailyFatsTarget) { _ in
                handleGoalParameterChange()
            }
            .onChange(of: viewModel.currentWeight) { newWeight in
                handleWeightChange(newWeight)
            }
            .alert("Goal Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .overlay(successMessageOverlay)
        }
        .onDisappear {
            // Cancel any pending weight update task
            weightUpdateTask?.cancel()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Navy blue base
            Color(red: 0.04, green: 0.08, blue: 0.15)
                .ignoresSafeArea()
            
            // Futuristic gradient overlays
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.05),
                    Color.clear,
                    Color.blue.opacity(0.04),
                    Color.clear,
                    Color.green.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - View Components
    
    private var saveButton: some View {
        GlassButton("Save", icon: "target", isLoading: viewModel.isLoading, style: .blue) {
            Task {
                await performSaveAction()
            }
        }
        .disabled(!viewModel.validateCurrentGoal() || viewModel.isLoading || !hasValidInput())
    }
    
    private var successMessageOverlay: some View {
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
    }
    
    // MARK: - Actions
    
    private func handleGoalParameterChange() {
        Task { @MainActor in
            checkForChanges()
            
            // Auto-save if we have valid input and changes
            if hasValidInput() && hasChanges {
                // Debounce auto-save to avoid excessive saves
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                
                if !Task.isCancelled && hasValidInput() && hasChanges {
                    await performAutoSave()
                }
            }
        }
    }
    
    private func handleWeightChange(_ newWeight: String) {
        // Cancel previous weight update task
        weightUpdateTask?.cancel()
        
        // Debounce weight updates to avoid excessive saves
        weightUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            if !Task.isCancelled {
                await viewModel.updateCurrentWeight(newWeight)
            }
        }
    }
    
    private func handleKeyboardDone() {
        if isCurrentWeightFocused {
            Task {
                await viewModel.updateCurrentWeight(viewModel.currentWeight)
            }
            isCurrentWeightFocused = false
        }
        if isTargetWeightFocused {
            isTargetWeightFocused = false
            validateTargetWeight()
        }
        if isWaterTargetFocused {
            isWaterTargetFocused = false
        }
        if isProteinTargetFocused {
            isProteinTargetFocused = false
        }
        if isCarbsTargetFocused {
            isCarbsTargetFocused = false
        }
        if isFatsTargetFocused {
            isFatsTargetFocused = false
        }
    }
    
    private func performSaveAction() async {
        guard let user = user else { return }
        
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
    
    private func performAutoSave() async {
        guard let user = user else { return }
        
        if viewModel.currentGoal != nil {
            await viewModel.updateGoal(for: user)
        } else {
            await viewModel.createGoal(for: user)
        }
        
        if !viewModel.showingError {
            // Notify other views that goal was updated (but don't show success message)
            NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
            hasChanges = false // Reset changes flag after successful save
        }
    }
    
    // MARK: - View Sections


    private var goalTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goal Type (Auto-detected)")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.calculatedGoalType.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(viewModel.calculatedGoalType.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !viewModel.currentWeight.isEmpty && !viewModel.targetWeight.isEmpty {
                            let currentWeight = Double(viewModel.currentWeight) ?? 0
                            let targetWeight = Double(viewModel.targetWeight) ?? 0
                            let difference = targetWeight - currentWeight
                            let direction = difference < 0 ? "lose" : (difference > 0 ? "gain" : "maintain")
                            let amount = abs(difference)
                            
                            if amount > 1.0 {
                                Text("Need to \(direction) \(amount, specifier: "%.1f") \(weightUnit)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
            }
        }
    }
    
    private var currentWeightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Weight")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                        .frame(width: 24, height: 24)
                    
                    Text("Current Weight")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    TextField("Enter weight", text: $viewModel.currentWeight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($isCurrentWeightFocused)
                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                        .onChange(of: viewModel.currentWeight) { newValue in
                            // Replace comma with period for decimal input
                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if correctedValue != newValue {
                                viewModel.currentWeight = correctedValue
                            }
                        }
                        .onSubmit {
                            Task {
                                await viewModel.updateCurrentWeight(viewModel.currentWeight)
                            }
                        }
                    
                    Text(weightUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var targetWeightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Target Weight")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.calculatedGoalType == .maintainWeight && viewModel.targetWeight.isEmpty {
                Text("Enter a target weight to enable Lose Weight or Gain Weight goals")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            
            GlassCard {
                HStack {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 24, height: 24)
                    
                    Text("Target Weight")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    TextField(viewModel.calculatedGoalType == .maintainWeight ? "Optional" : "Enter weight", text: $viewModel.targetWeight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($isTargetWeightFocused)
                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                        .onChange(of: viewModel.targetWeight) { newValue in
                            // Replace comma with period for decimal input
                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if correctedValue != newValue {
                                viewModel.targetWeight = correctedValue
                            }
                            validateTargetWeight()
                        }
                    
                    Text(weightUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Show validation error if any
            if let validationError = getTargetWeightValidationError() {
                Text(validationError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Show warning if any (only when no validation error)
            if let user = user, getTargetWeightValidationError() == nil,
               let warning = getTargetWeightWarning() {
                Text(warning)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
            
            // Show progress info
            if let user = user, !viewModel.targetWeight.isEmpty,
               let targetWeight = Double(viewModel.targetWeight),
               getTargetWeightValidationError() == nil {
                let difference = abs(targetWeight - user.weight)
                let direction = targetWeight > user.weight ? "gain" : "lose"
                Text("You need to \(direction) \(difference, specifier: "%.1f") \(weightUnit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var dailyWaterTargetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Water Goal")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 24, height: 24)
                    
                    Text("Daily Water Target")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    TextField("Enter amount", text: $viewModel.dailyWaterTarget)
                        .keyboardType(.decimalPad)
                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($isWaterTargetFocused)
                        .onChange(of: viewModel.dailyWaterTarget) { newValue in
                            // Replace comma with period for decimal input
                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if correctedValue != newValue {
                                viewModel.dailyWaterTarget = correctedValue
                            }
                        }
                    
                    Text("ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var dailyProteinTargetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Protein Goal")
                .font(.headline)
                .fontWeight(.semibold)

            GlassCard {
                HStack {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 24, height: 24)

                    Text("Daily Protein Target")
                        .font(.subheadline)

                    Spacer()

                    TextField("Enter amount", text: $viewModel.dailyProteinTarget)
                        .keyboardType(.decimalPad)
                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($isProteinTargetFocused)
                        .onChange(of: viewModel.dailyProteinTarget) { newValue in
                            // Replace comma with period for decimal input
                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if correctedValue != newValue {
                                viewModel.dailyProteinTarget = correctedValue
                            }
                            validateProteinTarget(correctedValue)
                        }

                    Text(currentUnitSystem == .metric ? "g" : "oz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Show validation message if needed
                if let validationMessage = getProteinValidationMessage() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var dailyCarbsTargetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Carbs Goal")
                .font(.headline)
                .fontWeight(.semibold)

            GlassCard {
                HStack {
                    Image(systemName: "carrot.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                        .frame(width: 24, height: 24)

                    Text("Daily Carbs Target")
                        .font(.subheadline)

                    Spacer()

                    TextField("Enter amount", text: $viewModel.dailyCarbsTarget)
                        .keyboardType(.decimalPad)
                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($isCarbsTargetFocused)
                        .onChange(of: viewModel.dailyCarbsTarget) { newValue in
                            // Replace comma with period for decimal input
                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if correctedValue != newValue {
                                viewModel.dailyCarbsTarget = correctedValue
                            }
                            validateCarbsTarget(correctedValue)
                        }

                    Text(currentUnitSystem == .metric ? "g" : "oz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Show validation message if needed
                if let validationMessage = getCarbsValidationMessage() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var dailyFatsTargetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Fats Goal")
                .font(.headline)
                .fontWeight(.semibold)

            GlassCard {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(.pink)
                        .frame(width: 24, height: 24)

                    Text("Daily Fats Target")
                        .font(.subheadline)

                    Spacer()

                    TextField("Enter amount", text: $viewModel.dailyFatsTarget)
                        .keyboardType(.decimalPad)
                        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($isFatsTargetFocused)
                        .onChange(of: viewModel.dailyFatsTarget) { newValue in
                            // Replace comma with period for decimal input
                            let correctedValue = newValue.replacingOccurrences(of: ",", with: ".")
                            if correctedValue != newValue {
                                viewModel.dailyFatsTarget = correctedValue
                            }
                            validateFatsTarget(correctedValue)
                        }

                    Text(currentUnitSystem == .metric ? "g" : "oz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Show validation message if needed
                if let validationMessage = getFatsValidationMessage() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var dailyCalorieAdjustmentSection: some View {
        Section {
            VStack(spacing: 12) {
                calorieTargetHeader
                
                if shouldShowDetailedCalorieInfo {
                    Divider()
                    calorieDetailsView
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Daily Calorie Adjustment")
        } footer: {
            calorieAdjustmentFooter
        }
    }
    
    private var calorieTargetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Calorie Target")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                calorieTargetSubtitle
            }
            
            Spacer()
            
            if viewModel.selectedGoalType != .maintainWeight {
                calorieAdjustmentDisplay
            }
        }
    }
    
    private var calorieTargetSubtitle: some View {
        Group {
            if viewModel.selectedGoalType == .maintainWeight {
                Text("Maintain current calorie balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let adjustment = viewModel.calculatedDailyCalorieAdjustment
                let adjustmentText = adjustment < 0 ? "Deficit" : "Surplus"
                let adjustmentColor: Color = adjustment < 0 ? .red : .green
                
                Text("\(adjustmentText) of \(Int(abs(adjustment))) calories/day")
                    .font(.subheadline)
                    .foregroundColor(adjustmentColor)
                    .fontWeight(.medium)
            }
        }
    }
    
    private var calorieAdjustmentDisplay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            let adjustment = viewModel.calculatedDailyCalorieAdjustment
            let sign = adjustment >= 0 ? "+" : ""
            Text("\(sign)\(Int(adjustment))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(adjustment < 0 ? .red : .green)
            Text("cal/day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var shouldShowDetailedCalorieInfo: Bool {
        viewModel.selectedGoalType != .maintainWeight && 
        !viewModel.targetWeight.isEmpty && 
        !viewModel.currentWeight.isEmpty
    }
    
    private var calorieDetailsView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Weekly Weight Change:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                let weeklyChange = viewModel.calculatedWeeklyChange
                let sign = weeklyChange >= 0 ? "+" : ""
                Text("\(sign)\(weeklyChange, specifier: "%.2f") \(weightUnit)/week")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(weeklyChange < 0 ? .red : .green)
            }
            
            if let targetWeight = Double(viewModel.targetWeight),
               let currentWeight = Double(viewModel.currentWeight) {
                let totalWeightChange = targetWeight - currentWeight
                let daysToGoal = viewModel.targetDate.timeIntervalSince(Date()) / (24 * 60 * 60)
                
                HStack {
                    Text("Time to Goal:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(daysToGoal)) days")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Total Weight Change:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    let sign = totalWeightChange >= 0 ? "+" : ""
                    Text("\(sign)\(totalWeightChange, specifier: "%.1f") \(weightUnit)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(totalWeightChange < 0 ? .red : .green)
                }
            }
        }
    }
    
    private var calorieAdjustmentFooter: some View {
        Group {
            if viewModel.selectedGoalType != .maintainWeight {
                Text("This is the daily calorie deficit/surplus needed to reach your target weight by the target date. Your Nutrition tab will show your progress toward this target.")
                    .font(.caption)
            } else {
                Text("For weight maintenance, focus on balancing calories consumed with calories burned.")
                    .font(.caption)
            }
        }
    }
    
    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Target Date")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 24, height: 24)
                    
                    Text("Target Date")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button(action: { showingDatePicker.toggle() }) {
                        Text(viewModel.targetDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
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
            
            // Show estimated time info
            if !viewModel.estimatedTimeToGoal.isEmpty && viewModel.estimatedTimeToGoal != "N/A" {
                let days = Int(viewModel.targetDate.timeIntervalSince(Date()) / (24 * 60 * 60))
                Text("Estimated time to goal: \(days) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
    
    private func loadUnitSystem() {
        if let savedUnit = UserDefaults.standard.string(forKey: "UnitSystem"),
           let unitSystem = UnitSystem(rawValue: savedUnit) {
            currentUnitSystem = unitSystem
        }
    }

    
    private var weightUnit: String {
        return currentUnitSystem == .metric ? "kg" : "lbs"
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
        let targetWeightChanged = (currentGoal.targetWeight != nil ? String(format: "%.1f", currentGoal.targetWeight!) : "") != viewModel.targetWeight
        let goalTypeChanged = currentGoal.type != viewModel.selectedGoalType
        let weeklyChangeChanged = abs(currentGoal.weeklyWeightChangeGoal - viewModel.weeklyWeightChangeGoal) > 0.01
        let targetDateChanged = currentGoal.targetDate != viewModel.targetDate
        let waterTargetChanged = String(currentGoal.dailyWaterTarget) != viewModel.dailyWaterTarget
        
        hasChanges = targetWeightChanged || goalTypeChanged || weeklyChangeChanged || targetDateChanged || waterTargetChanged
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
    
    private func getTargetWeightWarning() -> String? {
        guard let user = user else { return nil }
        return viewModel.getTargetWeightWarning(currentWeight: user.weight)
    }
    
    private func validateProteinTarget(_ value: String) {
        guard !value.isEmpty, let proteinValue = Double(value) else { return }
        
        // Convert to grams if using imperial
        let proteinInGrams = currentUnitSystem == .metric ? proteinValue : proteinValue * 28.35
        
        // Save to goal model
        if let user = user {
            Task {
                await viewModel.updateProteinTarget(proteinInGrams)
            }
        }
    }
    
    private func getProteinValidationMessage() -> String? {
        guard !viewModel.dailyProteinTarget.isEmpty, let proteinValue = Double(viewModel.dailyProteinTarget) else { return nil }

        // Convert to grams if using imperial
        let proteinInGrams = currentUnitSystem == .metric ? proteinValue : proteinValue * 28.35

        guard let user = user else { return nil }

        // Protein recommendations:
        // Sedentary: 0.8-1.2g/kg body weight
        // Active: 1.2-2.0g/kg body weight
        // Very active/athletes: 1.6-2.2g/kg body weight
        // Maximum safe intake: ~3.0g/kg body weight

        let bodyWeight = user.weight
        let minProtein = bodyWeight * 0.8
        let maxSafeProtein = bodyWeight * 3.0
        let recommendedMax = bodyWeight * 2.2

        if proteinInGrams < minProtein {
            return "Protein goal is below recommended minimum (\(Int(minProtein))g)"
        } else if proteinInGrams > maxSafeProtein {
            return "Protein goal exceeds safe limits. Maximum recommended: \(Int(maxSafeProtein))g"
        } else if proteinInGrams > recommendedMax {
            return "High protein goal. Ensure adequate hydration and kidney health"
        }

        return nil
    }

    private func validateCarbsTarget(_ value: String) {
        guard !value.isEmpty, let carbsValue = Double(value) else { return }

        // Convert to grams if using imperial
        let carbsInGrams = currentUnitSystem == .metric ? carbsValue : carbsValue * 28.35

        // Save to goal model
        if let user = user {
            Task {
                await viewModel.updateCarbsTarget(carbsInGrams)
            }
        }
    }

    private func getCarbsValidationMessage() -> String? {
        guard !viewModel.dailyCarbsTarget.isEmpty, let carbsValue = Double(viewModel.dailyCarbsTarget) else { return nil }

        // Convert to grams if using imperial
        let carbsInGrams = currentUnitSystem == .metric ? carbsValue : carbsValue * 28.35

        // Carbs recommendations:
        // Minimum: 130g/day (for brain function)
        // Low-carb: 50-150g/day
        // Moderate: 150-300g/day
        // High-carb: 300-500g/day
        // Maximum reasonable: ~600g/day

        if carbsInGrams < 50 {
            return "Very low carb goal. Ensure this aligns with your dietary plan"
        } else if carbsInGrams > 600 {
            return "Carbs goal seems very high. Consider consulting a nutritionist"
        } else if carbsInGrams < 130 {
            return "Low carb goal. Monitor energy levels and ensure adequate fiber intake"
        }

        return nil
    }

    private func validateFatsTarget(_ value: String) {
        guard !value.isEmpty, let fatsValue = Double(value) else { return }

        // Convert to grams if using imperial
        let fatsInGrams = currentUnitSystem == .metric ? fatsValue : fatsValue * 28.35

        // Save to goal model
        if let user = user {
            Task {
                await viewModel.updateFatsTarget(fatsInGrams)
            }
        }
    }

    private func getFatsValidationMessage() -> String? {
        guard !viewModel.dailyFatsTarget.isEmpty, let fatsValue = Double(viewModel.dailyFatsTarget) else { return nil }

        // Convert to grams if using imperial
        let fatsInGrams = currentUnitSystem == .metric ? fatsValue : fatsValue * 28.35

        guard let user = user else { return nil }

        // Fats recommendations:
        // Minimum: 20-35% of calories (or ~0.5-1g/kg body weight)
        // Low-fat: 20-30g/day
        // Moderate: 50-80g/day
        // High-fat/keto: 100-200g/day
        // Maximum reasonable: ~250g/day

        let bodyWeight = user.weight
        let minFats = bodyWeight * 0.5
        let recommendedMin = 30.0

        if fatsInGrams < recommendedMin {
            return "Low fat goal. Ensure adequate essential fatty acids intake"
        } else if fatsInGrams < minFats {
            return "Fat goal is below recommended minimum (\(Int(minFats))g for your weight)"
        } else if fatsInGrams > 250 {
            return "Fats goal seems very high. Ensure this aligns with your dietary plan"
        }

        return nil
    }
    
}

// MARK: - Extensions

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

// MARK: - Preview

// MARK: - Mock Services for Preview

class MockHealthKitService: HealthKitServiceProtocol {
    func requestAuthorization() async throws { }
    func saveDietaryEnergy(calories: Double, date: Date) async throws { }
    func saveDietaryProtein(protein: Double, date: Date) async throws { }
    func saveDietaryCarbs(carbs: Double, date: Date) async throws { }
    func saveDietaryFats(fats: Double, date: Date) async throws { }
    func saveWater(milliliters: Double, date: Date) async throws { }
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData] { return [] }
    func fetchActiveEnergy(for date: Date) async throws -> Double { return 0 }
    func fetchRestingEnergy(for date: Date) async throws -> Double { return 0 }
    func fetchTotalEnergyExpended(for date: Date) async throws -> Double { return 0 }
    func fetchWeight() async throws -> Double? { return nil }
    func saveWeight(_ weight: Double, date: Date) async throws { }
    func fetchDietaryEnergy(from startDate: Date, to endDate: Date) async throws -> Double { return 0 }
    func fetchDietaryProtein(from startDate: Date, to endDate: Date) async throws -> Double { return 0 }
    func fetchDietaryWater(from startDate: Date, to endDate: Date) async throws -> Double { return 0 }
    func observeWeightChanges() -> AnyPublisher<Double, Never> { return Just(0).eraseToAnyPublisher() }
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never> { return Just([]).eraseToAnyPublisher() }
    func observeEnergyChanges() -> AnyPublisher<(resting: Double, active: Double), Never> { return Just((resting: 0, active: 0)).eraseToAnyPublisher() }
    func manualRefresh() async throws { }
    func startBackgroundSync() { }
    func stopBackgroundSync() { }
    var isHealthKitAvailable: Bool { return false }
    var authorizationStatus: HKAuthorizationStatus { return .notDetermined }
    var syncStatus: AnyPublisher<SyncStatus, Never> { return Just(.idle).eraseToAnyPublisher() }
    var lastSyncDate: Date? { return nil }
}

struct GoalSettingView_Previews: PreviewProvider {
    static var previews: some View {
        GoalSettingView(
            calculationService: CalculationService(),
            dataService: DataService.shared,
            healthKitService: MockHealthKitService()
        )
    }
}