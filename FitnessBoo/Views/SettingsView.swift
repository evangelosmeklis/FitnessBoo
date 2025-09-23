//
//  SettingsView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import SwiftUI
import Combine
import HealthKit

struct SettingsView: View {
    @StateObject private var goalViewModel: GoalViewModel
    @State private var selectedUnitSystem: UnitSystem = .metric
    @State private var showSuccessMessage = false
    @State private var user: User?
    
    init(calculationService: CalculationServiceProtocol = CalculationService(), 
         dataService: DataServiceProtocol = DataService.shared,
         healthKitService: HealthKitServiceProtocol) {
        self._goalViewModel = StateObject(wrappedValue: GoalViewModel(
            calculationService: calculationService,
            dataService: dataService,
            healthKitService: healthKitService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Unit System Section
                    unitSystemSection
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadSettings()
            }
            .onAppear {
                Task {
                    await loadSettings()
                }
            }
            .overlay(successMessageOverlay)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.8),
                Color.cyan.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Unit System Section
    
    private var unitSystemSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unit System")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(UnitSystem.allCases, id: \.self) { unitSystem in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(unitSystem.displayName)
                                    .font(.headline)
                                
                                Text(unitSystem == .metric ? "Kilograms, centimeters, milliliters" : "Pounds, feet/inches, fluid ounces")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedUnitSystem == unitSystem {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title2)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedUnitSystem != unitSystem {
                            selectedUnitSystem = unitSystem
                            Task {
                                await updateUnitSystem()
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    
    private var successMessageOverlay: some View {
        Group {
            if showSuccessMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Settings updated successfully!")
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
    
    // MARK: - Helper Methods
    
    private func loadSettings() async {
        // Load user data
        do {
            user = try await DataService.shared.fetchUser()
            if let user = user {
                await goalViewModel.loadCurrentGoal(for: user)
            }
        } catch {
            print("Error loading user data: \(error)")
        }
        
        // Load saved unit system preference
        if let savedUnit = UserDefaults.standard.string(forKey: "UnitSystem"),
           let unitSystem = UnitSystem(rawValue: savedUnit) {
            selectedUnitSystem = unitSystem
        }
        
    }
    
    private func updateUnitSystem() async {
        // Save preference
        UserDefaults.standard.set(selectedUnitSystem.rawValue, forKey: "UnitSystem")
        
        // Convert user weight if needed
        if var user = user {
            if selectedUnitSystem == .imperial {
                // Convert kg to lbs
                user.weight = user.weight * 2.20462
            } else {
                // Convert lbs to kg
                user.weight = user.weight / 2.20462
            }
            
            do {
                try await DataService.shared.saveUser(user)
                self.user = user
                
                // Update goal with new weight
                await goalViewModel.updateCurrentWeight(String(format: "%.1f", user.weight))
                
                // Notify other tabs
                NotificationCenter.default.post(name: NSNotification.Name("WeightDataUpdated"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("UnitSystemChanged"), object: selectedUnitSystem)
                
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showSuccessMessage = false
                }
            } catch {
                print("Error updating user weight: \(error)")
            }
        }
    }
    
    
}


// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            calculationService: CalculationService(),
            dataService: DataService.shared,
            healthKitService: MockHealthKitService()
        )
    }
}

