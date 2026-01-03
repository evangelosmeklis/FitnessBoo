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

    // Notification settings
    @State private var notificationsEnabled = false
    @State private var calorieNotificationsEnabled = false
    @State private var waterNotificationsEnabled = false
    @State private var proteinNotificationsEnabled = false
    @State private var calorieNotificationTimes: [Date] = []
    @State private var waterNotificationTimes: [Date] = []
    @State private var proteinNotificationTimes: [Date] = []
    @State private var showingCalorieTimePicker = false
    @State private var showingWaterTimePicker = false
    @State private var showingProteinTimePicker = false
    
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
                    // Notifications Section
                    notificationsSection

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
            .sheet(isPresented: $showingCalorieTimePicker) {
                TimePickerSheet(times: $calorieNotificationTimes, title: "Calorie Reminders")
            }
            .sheet(isPresented: $showingWaterTimePicker) {
                TimePickerSheet(times: $waterNotificationTimes, title: "Water Reminders")
            }
            .sheet(isPresented: $showingProteinTimePicker) {
                TimePickerSheet(times: $proteinNotificationTimes, title: "Protein Reminders")
            }
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
                    Color.blue.opacity(0.05),
                    Color.clear,
                    Color.cyan.opacity(0.04),
                    Color.clear,
                    Color.green.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Appearance Section


    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.blue)
                Text("Notifications")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            VStack(spacing: 12) {
                // Master Toggle
                GlassCard(cornerRadius: 16) {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(.blue)
                            }

                            Text("Enable Notifications")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .onChange(of: notificationsEnabled) { newValue in
                        handleMasterToggle(enabled: newValue)
                    }
                }

                if notificationsEnabled {
                    // Calorie Notifications
                    notificationToggle(
                        title: "Calorie Progress",
                        icon: "bolt.fill",
                        color: .cyan,
                        isEnabled: $calorieNotificationsEnabled,
                        times: calorieNotificationTimes,
                        onToggle: { enabled in
                            handleNotificationToggle(type: .calorie, enabled: enabled)
                        },
                        onConfigureTimes: {
                            showingCalorieTimePicker = true
                        }
                    )

                    // Water Notifications
                    notificationToggle(
                        title: "Water Reminders",
                        icon: "drop.fill",
                        color: Color(red: 0.0, green: 0.8, blue: 0.8),
                        isEnabled: $waterNotificationsEnabled,
                        times: waterNotificationTimes,
                        onToggle: { enabled in
                            handleNotificationToggle(type: .water, enabled: enabled)
                        },
                        onConfigureTimes: {
                            showingWaterTimePicker = true
                        }
                    )

                    // Protein Notifications
                    notificationToggle(
                        title: "Protein Check",
                        icon: "leaf.fill",
                        color: .green,
                        isEnabled: $proteinNotificationsEnabled,
                        times: proteinNotificationTimes,
                        onToggle: { enabled in
                            handleNotificationToggle(type: .protein, enabled: enabled)
                        },
                        onConfigureTimes: {
                            showingProteinTimePicker = true
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func notificationToggle(
        title: String,
        icon: String,
        color: Color,
        isEnabled: Binding<Bool>,
        times: [Date],
        onToggle: @escaping (Bool) -> Void,
        onConfigureTimes: @escaping () -> Void
    ) -> some View {
        GlassCard(cornerRadius: 16) {
            VStack(spacing: 12) {
                Toggle(isOn: isEnabled) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.15))
                                .frame(width: 36, height: 36)

                            Image(systemName: icon)
                                .foregroundStyle(color)
                                .font(.system(size: 14))
                        }

                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .onChange(of: isEnabled.wrappedValue) { newValue in
                    onToggle(newValue)
                }

                if isEnabled.wrappedValue {
                    Divider()
                    
                    // Display current times if any
                    if !times.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(times.prefix(3).enumerated()), id: \.offset) { _, time in
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(color)
                                        .font(.caption2)
                                    
                                    Text(time.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if times.count > 3 {
                                Text("+ \(times.count - 3) more")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 20)
                            }
                        }
                        
                        Divider()
                    }

                    Button(action: onConfigureTimes) {
                        HStack {
                            Image(systemName: times.isEmpty ? "plus.circle" : "pencil.circle")
                                .foregroundStyle(color)
                            
                            Text(times.isEmpty ? "Add reminder times" : "Manage reminders")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(color)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
                    .foregroundStyle(.green)
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
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: unitSystem == .metric ? "123.circle.fill" : "textformat.abc")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.green)
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

        // Load notification preferences
        loadNotificationPreferences()
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

    // MARK: - Notification Handlers

    private func handleMasterToggle(enabled: Bool) {
        if !enabled {
            // Disable all notification types
            calorieNotificationsEnabled = false
            waterNotificationsEnabled = false
            proteinNotificationsEnabled = false

            // Cancel all scheduled notifications
            NotificationService.shared.cancelAllNotifications()

            // Clear saved times
            calorieNotificationTimes.removeAll()
            waterNotificationTimes.removeAll()
            proteinNotificationTimes.removeAll()

            // Save preferences
            saveNotificationPreferences()
        } else {
            // Request notification permission
            Task {
                do {
                    try await NotificationService.shared.requestAuthorization()
                } catch {
                    print("Failed to request notification authorization: \(error)")
                    notificationsEnabled = false
                }
            }
        }
    }

    private func handleNotificationToggle(type: NotificationType, enabled: Bool) {
        if !enabled {
            // Cancel notifications for this type
            NotificationService.shared.cancelNotifications(for: type)

            // Clear times for this type
            switch type {
            case .calorie:
                calorieNotificationTimes.removeAll()
            case .water:
                waterNotificationTimes.removeAll()
            case .protein:
                proteinNotificationTimes.removeAll()
            }
        }

        saveNotificationPreferences()
    }

    private func saveNotificationPreferences() {
        UserDefaults.standard.set(notificationsEnabled, forKey: "NotificationsEnabled")
        UserDefaults.standard.set(calorieNotificationsEnabled, forKey: "CalorieNotificationsEnabled")
        UserDefaults.standard.set(waterNotificationsEnabled, forKey: "WaterNotificationsEnabled")
        UserDefaults.standard.set(proteinNotificationsEnabled, forKey: "ProteinNotificationsEnabled")

        // Save notification times
        if let calorieData = try? JSONEncoder().encode(calorieNotificationTimes) {
            UserDefaults.standard.set(calorieData, forKey: "CalorieNotificationTimes")
        }
        if let waterData = try? JSONEncoder().encode(waterNotificationTimes) {
            UserDefaults.standard.set(waterData, forKey: "WaterNotificationTimes")
        }
        if let proteinData = try? JSONEncoder().encode(proteinNotificationTimes) {
            UserDefaults.standard.set(proteinData, forKey: "ProteinNotificationTimes")
        }

        // Schedule notifications based on saved times
        scheduleNotifications()
    }

    private func loadNotificationPreferences() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: "NotificationsEnabled")
        calorieNotificationsEnabled = UserDefaults.standard.bool(forKey: "CalorieNotificationsEnabled")
        waterNotificationsEnabled = UserDefaults.standard.bool(forKey: "WaterNotificationsEnabled")
        proteinNotificationsEnabled = UserDefaults.standard.bool(forKey: "ProteinNotificationsEnabled")

        // Load notification times
        if let calorieData = UserDefaults.standard.data(forKey: "CalorieNotificationTimes"),
           let times = try? JSONDecoder().decode([Date].self, from: calorieData) {
            calorieNotificationTimes = times
        }
        if let waterData = UserDefaults.standard.data(forKey: "WaterNotificationTimes"),
           let times = try? JSONDecoder().decode([Date].self, from: waterData) {
            waterNotificationTimes = times
        }
        if let proteinData = UserDefaults.standard.data(forKey: "ProteinNotificationTimes"),
           let times = try? JSONDecoder().decode([Date].self, from: proteinData) {
            proteinNotificationTimes = times
        }
    }

    private func scheduleNotifications() {
        // Cancel all existing notifications first
        NotificationService.shared.cancelAllNotifications()

        // Schedule calorie notifications
        if calorieNotificationsEnabled {
            for time in calorieNotificationTimes {
                NotificationService.shared.scheduleNotification(for: .calorie, at: time)
            }
        }

        // Schedule water notifications
        if waterNotificationsEnabled {
            for time in waterNotificationTimes {
                NotificationService.shared.scheduleNotification(for: .water, at: time)
            }
        }

        // Schedule protein notifications
        if proteinNotificationsEnabled {
            for time in proteinNotificationTimes {
                NotificationService.shared.scheduleNotification(for: .protein, at: time)
            }
        }
    }
}

enum NotificationType {
    case calorie
    case water
    case protein
}

// MARK: - Time Picker Sheet

struct TimePickerSheet: View {
    @Binding var times: [Date]
    let title: String
    @State private var newTime = Date()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Add new time
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "clock.badge.plus")
                                .foregroundStyle(.cyan)
                            Text("Add Reminder Time")
                                .font(.headline)
                        }

                        GlassCard(cornerRadius: 16) {
                            VStack(spacing: 16) {
                                DatePicker("Time", selection: $newTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()

                                Button(action: addTime) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Reminder")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.cyan)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // List of saved times
                    if !times.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundStyle(.green)
                                Text("Scheduled Reminders (\(times.count))")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            LazyVStack(spacing: 12) {
                                ForEach(Array(times.enumerated()), id: \.offset) { index, time in
                                    GlassCard(cornerRadius: 16) {
                                        HStack(spacing: 16) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.cyan.opacity(0.2))
                                                    .frame(width: 44, height: 44)
                                                
                                                Image(systemName: "clock.fill")
                                                    .foregroundStyle(.cyan)
                                                    .font(.system(size: 18))
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(time.formatted(date: .omitted, time: .shortened))
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                
                                                Text("Daily reminder")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button(action: {
                                                removeTime(at: index)
                                            }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.red.opacity(0.15))
                                                        .frame(width: 36, height: 36)
                                                    
                                                    Image(systemName: "trash.fill")
                                                        .foregroundStyle(.red)
                                                        .font(.system(size: 14))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No reminders set")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("Add your first reminder above")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(
                ZStack {
                    // Navy blue base
                    Color(red: 0.04, green: 0.08, blue: 0.15)
                        .ignoresSafeArea()
                    
                    // Subtle gradient overlays
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.05),
                            Color.clear,
                            Color.blue.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    private func addTime() {
        // Check if this time already exists
        let calendar = Calendar.current
        let newComponents = calendar.dateComponents([.hour, .minute], from: newTime)

        let alreadyExists = times.contains { existingTime in
            let existingComponents = calendar.dateComponents([.hour, .minute], from: existingTime)
            return newComponents.hour == existingComponents.hour &&
                   newComponents.minute == existingComponents.minute
        }

        if !alreadyExists {
            times.append(newTime)
            // Sort times chronologically
            times.sort()
        }
    }

    private func removeTime(at index: Int) {
        times.remove(at: index)
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

