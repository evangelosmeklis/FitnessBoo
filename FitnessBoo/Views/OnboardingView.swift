//
//  OnboardingView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var currentStep = 0
    @State private var showingDashboard = false
    
    private let totalSteps = 5
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Progress indicator
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
                
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStepView()
                    case 1:
                        BasicInfoStepView(viewModel: viewModel)
                    case 2:
                        PhysicalInfoStepView(viewModel: viewModel)
                    case 3:
                        ActivityLevelStepView(viewModel: viewModel)
                    case 4:
                        ReviewStepView(viewModel: viewModel)
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut, value: currentStep)
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == totalSteps - 1 ? "Complete Setup" : "Next") {
                        if currentStep == totalSteps - 1 {
                            completeOnboarding()
                        } else {
                            nextStep()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isNextButtonDisabled)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Setup Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .fullScreenCover(isPresented: $showingDashboard) {
                // TODO: Replace with actual dashboard view
                Text("Dashboard - Setup Complete!")
                    .font(.title)
            }
        }
    }
    
    private var isNextButtonDisabled: Bool {
        switch currentStep {
        case 1:
            return viewModel.age.isEmpty || viewModel.ageError != nil
        case 2:
            return viewModel.weight.isEmpty || viewModel.height.isEmpty ||
                   viewModel.weightError != nil || viewModel.heightError != nil
        case 4:
            return viewModel.isLoading
        default:
            return false
        }
    }
    
    private func nextStep() {
        // Validate current step before proceeding
        switch currentStep {
        case 1:
            guard viewModel.validateAge() else { return }
        case 2:
            guard viewModel.validateWeight() && viewModel.validateHeight() else { return }
        default:
            break
        }
        
        withAnimation {
            currentStep += 1
        }
    }
    
    private func completeOnboarding() {
        Task {
            if let user = await viewModel.createUser() {
                // TODO: Save user to persistence layer
                print("User created successfully: \(user)")
                showingDashboard = true
            }
        }
    }
}

// MARK: - Step Views

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to FitnessBoo!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Let's set up your profile to provide personalized fitness and nutrition recommendations.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
}

struct BasicInfoStepView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Basic Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Age")
                        .font(.headline)
                    
                    TextField("Enter your age", text: $viewModel.age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    
                    if let error = viewModel.ageError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Gender")
                        .font(.headline)
                    
                    Picker("Gender", selection: $viewModel.gender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Preferred Units")
                        .font(.headline)
                    
                    Picker("Units", selection: $viewModel.preferredUnits) {
                        ForEach(UnitSystem.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

struct PhysicalInfoStepView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Physical Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Weight (\(viewModel.preferredUnits == .metric ? "kg" : "lbs"))")
                        .font(.headline)
                    
                    TextField("Enter your weight", text: $viewModel.weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    
                    if let error = viewModel.weightError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Height (\(viewModel.preferredUnits == .metric ? "cm" : "inches"))")
                        .font(.headline)
                    
                    TextField("Enter your height", text: $viewModel.height)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    
                    if let error = viewModel.heightError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct ActivityLevelStepView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Activity Level")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select your typical activity level to calculate your daily calorie needs.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button(action: {
                        viewModel.activityLevel = level
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.activityLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.activityLevel == level ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.activityLevel == level ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ReviewStepView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Review Your Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 15) {
                ReviewRow(title: "Age", value: "\(viewModel.age) years")
                ReviewRow(title: "Gender", value: viewModel.gender.displayName)
                ReviewRow(title: "Weight", value: "\(viewModel.weight) \(viewModel.preferredUnits == .metric ? "kg" : "lbs")")
                ReviewRow(title: "Height", value: "\(viewModel.height) \(viewModel.preferredUnits == .metric ? "cm" : "inches")")
                ReviewRow(title: "Activity Level", value: viewModel.activityLevel.displayName)
                ReviewRow(title: "Units", value: viewModel.preferredUnits.displayName)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            if viewModel.isLoading {
                ProgressView("Creating your profile...")
                    .padding()
            }
        }
    }
}

struct ReviewRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    OnboardingView()
}