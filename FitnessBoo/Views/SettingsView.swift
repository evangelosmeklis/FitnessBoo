//
//  SettingsView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import SwiftUI
import Combine
import HealthKit

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"

    var displayName: String {
        return self.rawValue
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}

struct SettingsView: View {
    @StateObject private var goalViewModel: GoalViewModel
    @State private var selectedUnitSystem: UnitSystem = .metric
    @State private var selectedAppearance: AppearanceMode = .auto
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
                    // Appearance Section
                    appearanceSection

                    // Unit System Section
                    unitSystemSection
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(backgroundGradient)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundStyle(.purple)
                Text("Appearance")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            VStack(spacing: 12) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    GlassCard(cornerRadius: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(getAppearanceColor(for: mode).opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: mode.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(getAppearanceColor(for: mode))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text(getAppearanceDescription(for: mode))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedAppearance == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedAppearance != mode {
                            selectedAppearance = mode
                            updateAppearance()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unit System Section
    
    private var unitSystemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ruler.fill")
                    .foregroundStyle(.orange)
                Text("Unit System")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            VStack(spacing: 12) {
                ForEach(UnitSystem.allCases, id: \.self) { unitSystem in
                    GlassCard(cornerRadius: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: unitSystem == .metric ? "123.circle.fill" : "textformat.abc")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(unitSystem.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text(unitSystem == .metric ? "Kilograms, centimeters, milliliters" : "Pounds, feet/inches, fluid ounces")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedUnitSystem == unitSystem {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
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

    private func getAppearanceColor(for mode: AppearanceMode) -> Color {
        switch mode {
        case .light: return .yellow
        case .dark: return .indigo
        case .auto: return .purple
        }
    }

    private func getAppearanceDescription(for mode: AppearanceMode) -> String {
        switch mode {
        case .light: return "Always use light theme"
        case .dark: return "Always use dark theme"
        case .auto: return "Match system settings"
        }
    }

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

        // Load saved appearance preference
        if let savedAppearance = UserDefaults.standard.string(forKey: "AppearanceMode"),
           let appearance = AppearanceMode(rawValue: savedAppearance) {
            selectedAppearance = appearance
        }
    }

    private func updateAppearance() {
        UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "AppearanceMode")
        NotificationCenter.default.post(name: NSNotification.Name("AppearanceModeChanged"), object: selectedAppearance)

        showSuccessMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showSuccessMessage = false
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

