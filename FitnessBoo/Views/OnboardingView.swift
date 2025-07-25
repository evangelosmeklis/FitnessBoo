//
//  OnboardingView.swift
//  FitnessBoo
//
//  Created by Kiro on 23/7/25.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = UserProfileViewModel(dataService: DataService.shared)
    @State private var currentStep = 0

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    private let totalSteps = 6
    
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
                        HealthKitPermissionStepView()
                    case 5:
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

        }
    }
    
    private var isNextButtonDisabled: Bool {
        switch currentStep {
        case 1:
            return false // Skip age validation
        case 2:
            return viewModel.weight.isEmpty || viewModel.weightError != nil
        case 5:
            return viewModel.isLoading
        default:
            return false
        }
    }
    
    private func nextStep() {
        // Validate current step before proceeding
        switch currentStep {
        case 1:
            break // Skip age validation
        case 2:
            guard viewModel.validateWeight() else { return }
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
                do {
                    try await DataService.shared.saveUser(user)
                    print("User created successfully: \(user)")
                    await MainActor.run {
                        hasCompletedOnboarding = true
                    }
                } catch {
                    print("Failed to save user: \(error)")
                    await MainActor.run {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showingError = true
                    }
                }
            } else {
                print("Failed to create user")
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
                    Text("Personal Information")
                        .font(.headline)
                    
                    Text("We'll get your personal information from HealthKit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                    Text("Height")
                        .font(.headline)
                    
                    Text("Height will be obtained from HealthKit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            
            Text("Activity level will be determined from your HealthKit workout data.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                Text("We'll automatically track your activity through:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("Daily step count")
                    }
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Workout sessions")
                    }
                    HStack {
                        Image(systemName: "flame.fill")
                        Text("Active energy burned")
                    }
                }
                .foregroundColor(.secondary)
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

struct HealthKitPermissionStepView: View {
    @State private var hasRequestedPermission = false
    @State private var permissionStatus = "Not Requested"
    
    private let healthKitService = HealthKitService()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Health Data Access")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("FitnessBoo can integrate with the Health app to provide accurate calorie tracking using your active and resting energy data.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "flame.fill",
                    title: "Active Energy Tracking",
                    description: "Track calories burned during workouts and activities"
                )
                
                FeatureRow(
                    icon: "bed.double.fill",
                    title: "Resting Energy Tracking",
                    description: "Monitor your basal metabolic rate throughout the day"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Real-time Balance",
                    description: "See your caloric balance update live throughout the day"
                )
            }
            
            if !hasRequestedPermission {
                Button("Grant Health Access") {
                    requestHealthKitPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 8) {
                    Text("Status: \(permissionStatus)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("You can change these permissions anytime in the Health app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private func requestHealthKitPermission() {
        hasRequestedPermission = true
        permissionStatus = "Requesting..."
        
        Task {
            do {
                try await healthKitService.requestAuthorization()
                await MainActor.run {
                    permissionStatus = "Completed"
                }
            } catch {
                await MainActor.run {
                    permissionStatus = "Limited (will use calculated values)"
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
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