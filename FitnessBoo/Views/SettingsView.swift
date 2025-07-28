//
//  SettingsView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import SwiftUI
import UserNotifications
import Combine
import HealthKit

struct SettingsView: View {
    @StateObject private var goalViewModel: GoalViewModel
    @State private var selectedUnitSystem: UnitSystem = .metric
    @State private var calorieNotificationsEnabled = false
    @State private var waterNotificationsEnabled = false
    @State private var proteinNotificationsEnabled = false
    @State private var notificationFrequency = 2 // Up to 3 times a day
    @State private var notificationTime1 = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notificationTime2 = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notificationTime3 = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showingResetConfirmation = false
    @State private var isResetting = false
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
                    
                    // Notification Settings Section
                    notificationSettingsSection
                    
                    // Data Management Section
                    dataManagementSection
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
            .confirmationDialog("Reset All Data", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Reset All Data", role: .destructive) {
                    Task {
                        await resetAllData()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your goals, food entries, and nutrition data. This action cannot be undone. HealthKit data will not be affected.")
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
    
    // MARK: - Notification Settings Section
    
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Progress Notifications")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                VStack(spacing: 16) {
                    // Notification toggles
                    VStack(spacing: 12) {
                        NotificationToggleRow(
                            title: "Calorie Progress",
                            subtitle: "Get updates on your daily calorie goal",
                            icon: "flame.fill",
                            color: .orange,
                            isEnabled: $calorieNotificationsEnabled,
                            onToggle: updateNotificationSchedules
                        )
                        
                        Divider()
                        
                        NotificationToggleRow(
                            title: "Water Intake",
                            subtitle: "Reminders to stay hydrated",
                            icon: "drop.fill",
                            color: .blue,
                            isEnabled: $waterNotificationsEnabled,
                            onToggle: updateNotificationSchedules
                        )
                        
                        Divider()
                        
                        NotificationToggleRow(
                            title: "Protein Goal",
                            subtitle: "Track your daily protein intake",
                            icon: "leaf.fill",
                            color: .green,
                            isEnabled: $proteinNotificationsEnabled,
                            onToggle: updateNotificationSchedules
                        )
                    }
                    
                    if calorieNotificationsEnabled || waterNotificationsEnabled || proteinNotificationsEnabled {
                        Divider()
                        
                        HStack {
                            Text("Notifications per day")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Picker("Frequency", selection: $notificationFrequency) {
                                Text("1x").tag(1)
                                Text("2x").tag(2)
                                Text("3x").tag(3)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 120)
                            .onChange(of: notificationFrequency) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "NotificationFrequency")
                                updateNotificationSchedules()
                            }
                        }
                        
                        
                        // Time pickers for notification schedule
                        if notificationFrequency >= 1 {
                            Divider()
                            
                            VStack(spacing: 12) {
                                Text("Notification Times")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack {
                                    Text("1st notification:")
                                        .font(.caption)
                                    Spacer()
                                    DatePicker("", selection: $notificationTime1, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .onChange(of: notificationTime1) { newValue in
                                            saveNotificationTime(1, time: newValue)
                                        }
                                }
                                
                                if notificationFrequency >= 2 {
                                    HStack {
                                        Text("2nd notification:")
                                            .font(.caption)
                                        Spacer()
                                        DatePicker("", selection: $notificationTime2, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .onChange(of: notificationTime2) { newValue in
                                                saveNotificationTime(2, time: newValue)
                                            }
                                    }
                                }
                                
                                if notificationFrequency >= 3 {
                                    HStack {
                                        Text("3rd notification:")
                                            .font(.caption)
                                        Spacer()
                                        DatePicker("", selection: $notificationTime3, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .onChange(of: notificationTime3) { newValue in
                                                saveNotificationTime(3, time: newValue)
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Management")
                .font(.headline)
                .fontWeight(.semibold)
            
            GlassCard {
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset All Data")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Text("Permanently delete all app data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if isResetting {
                            SwiftUI.ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disabled(isResetting)
            }
            
            Text("This will permanently delete all your goals, food entries, and nutrition data from the app. HealthKit data will remain unchanged.")
                .font(.caption)
                .foregroundColor(.secondary)
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
        
        // Load notification settings
        calorieNotificationsEnabled = UserDefaults.standard.bool(forKey: "CalorieProgressNotificationsEnabled")
        waterNotificationsEnabled = UserDefaults.standard.bool(forKey: "WaterIntakeNotificationsEnabled")
        proteinNotificationsEnabled = UserDefaults.standard.bool(forKey: "ProteinGoalNotificationsEnabled")
        notificationFrequency = UserDefaults.standard.integer(forKey: "NotificationFrequency")
        if notificationFrequency == 0 { notificationFrequency = 2 } // Default to 2x per day
        
        // Load notification times
        if let time1Data = UserDefaults.standard.object(forKey: "NotificationTime1") as? Date {
            notificationTime1 = time1Data
        }
        if let time2Data = UserDefaults.standard.object(forKey: "NotificationTime2") as? Date {
            notificationTime2 = time2Data
        }
        if let time3Data = UserDefaults.standard.object(forKey: "NotificationTime3") as? Date {
            notificationTime3 = time3Data
        }
        
        // Schedule notifications based on loaded settings
        updateNotificationSchedules()
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
                await goalViewModel.updateCurrentWeight(String(user.weight))
                
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
    
    private func resetAllData() async {
        isResetting = true
        
        do {
            // Reset all app data through DataService
            try await DataService.shared.resetAllData()
            
            // Reset the view model
            goalViewModel.resetToDefaults()
            
            // Clear user state
            user = nil
            
            // Post notifications to refresh all tabs
            NotificationCenter.default.post(name: NSNotification.Name("GoalUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("WeightDataUpdated"), object: nil)
            NotificationCenter.default.post(name: .nutritionDataUpdated, object: nil)
            
            // Show success message
            showSuccessMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showSuccessMessage = false
            }
            
        } catch {
            print("Failed to reset data: \(error.localizedDescription)")
        }
        
        isResetting = false
    }
    
    private func saveNotificationTime(_ index: Int, time: Date) {
        UserDefaults.standard.set(time, forKey: "NotificationTime\(index)")
        updateNotificationSchedules()
    }
    
    private func updateNotificationSchedules() {
        // First check if any notifications are enabled
        let anyEnabled = calorieNotificationsEnabled || waterNotificationsEnabled || proteinNotificationsEnabled
        
        guard anyEnabled else {
            // If no notifications enabled, clear all
            NotificationService.shared.clearAllProgressNotifications()
            return
        }
        
        // Check notification permission status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // Request permission first
                    Task {
                        do {
                            try await NotificationService.shared.requestAuthorization()
                            await self.scheduleNotifications()
                        } catch {
                            print("Failed to get notification permission: \(error)")
                        }
                    }
                case .authorized, .provisional:
                    // Permission granted, schedule notifications
                    Task {
                        await self.scheduleNotifications()
                    }
                case .denied:
                    // Permission denied, show alert
                    print("Notification permission denied. User needs to enable in Settings app.")
                    // Could show an alert here directing user to Settings
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func scheduleNotifications() async {
        let times = getNotificationTimes()
        
        NotificationService.shared.scheduleCalorieProgressNotifications(
            times: times,
            enabled: calorieNotificationsEnabled
        )
        
        NotificationService.shared.scheduleWaterProgressNotifications(
            times: times,
            enabled: waterNotificationsEnabled
        )
        
        NotificationService.shared.scheduleProteinProgressNotifications(
            times: times,
            enabled: proteinNotificationsEnabled
        )
    }
    
    private func getNotificationTimes() -> [Date] {
        var times: [Date] = []
        
        if notificationFrequency >= 1 {
            times.append(notificationTime1)
        }
        if notificationFrequency >= 2 {
            times.append(notificationTime2)
        }
        if notificationFrequency >= 3 {
            times.append(notificationTime3)
        }
        
        return times
    }
}

// MARK: - Notification Toggle Row

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool
    let onToggle: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .onChange(of: isEnabled) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "\(title.replacingOccurrences(of: " ", with: ""))NotificationsEnabled")
                    
                    if newValue {
                        requestNotificationPermission()
                    }
                    
                    onToggle?()
                }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
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

