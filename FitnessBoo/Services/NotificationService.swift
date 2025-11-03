//
//  NotificationService.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import Foundation
import UserNotifications

protocol NotificationServiceProtocol {
    func requestAuthorization() async throws
    func scheduleDailySummaryNotification(hour: Int, minute: Int)
    func scheduleProgressNotification(title: String, body: String, after seconds: TimeInterval)
    func scheduleCalorieProgressNotifications(times: [Date], enabled: Bool)
    func scheduleWaterProgressNotifications(times: [Date], enabled: Bool)
    func scheduleProteinProgressNotifications(times: [Date], enabled: Bool)
    func clearAllProgressNotifications()
}

class NotificationService: NSObject, NotificationServiceProtocol, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }
    
    func scheduleDailySummaryNotification(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Summary"
        content.body = "See how you did today!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailySummary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleProgressNotification(title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleCalorieProgressNotifications(times: [Date], enabled: Bool) {
        clearNotifications(withPrefix: "calorie_progress")
        
        guard enabled else { return }
        
        // Add a small delay to ensure clearing completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task {
                for (index, time) in times.enumerated() {
                    let content = UNMutableNotificationContent()
                    content.title = "🔥 Calorie Progress"
                    content.body = await self.getCalorieProgressMessage()
                    content.sound = .default
                    content.categoryIdentifier = "FITNESS_PROGRESS"
                    
                    self.scheduleNotificationForTime(time: time, 
                                              identifier: "calorie_progress_\(index)", 
                                              content: content,
                                              index: index,
                                              type: "calorie")
                }
            }
        }
    }
    
    func scheduleWaterProgressNotifications(times: [Date], enabled: Bool) {
        clearNotifications(withPrefix: "water_progress")
        
        guard enabled else { return }
        
        // Add a small delay to ensure clearing completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task {
                for (index, time) in times.enumerated() {
                    let content = UNMutableNotificationContent()
                    content.title = "💧 Water Progress"
                    content.body = await self.getWaterProgressMessage()
                    content.sound = .default
                    content.categoryIdentifier = "FITNESS_PROGRESS"
                    
                    self.scheduleNotificationForTime(time: time, 
                                              identifier: "water_progress_\(index)", 
                                              content: content,
                                              index: index,
                                              type: "water")
                }
            }
        }
    }
    
    func scheduleProteinProgressNotifications(times: [Date], enabled: Bool) {
        clearNotifications(withPrefix: "protein_progress")
        
        guard enabled else { return }
        
        // Add a small delay to ensure clearing completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for (index, time) in times.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "🥩 Protein Check"
                content.body = "Don't forget to track your protein intake today!"
                content.sound = .default
                content.categoryIdentifier = "FITNESS_PROGRESS"
                
                self.scheduleNotificationForTime(time: time, 
                                          identifier: "protein_progress_\(index)", 
                                          content: content,
                                          index: index,
                                          type: "protein")
            }
        }
    }
    
    func clearAllProgressNotifications() {
        clearNotifications(withPrefix: "calorie_progress")
        clearNotifications(withPrefix: "water_progress")
        clearNotifications(withPrefix: "protein_progress")
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancelNotifications(for type: NotificationType) {
        let prefix: String
        switch type {
        case .calorie:
            prefix = "calorie_progress"
        case .water:
            prefix = "water_progress"
        case .protein:
            prefix = "protein_progress"
        }
        clearNotifications(withPrefix: prefix)
    }

    func scheduleNotification(for type: NotificationType, at time: Date) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "FITNESS_PROGRESS"

        let prefix: String
        switch type {
        case .calorie:
            content.title = "🔥 Calorie Progress"
            content.body = "Time to check your calorie balance!"
            prefix = "calorie_progress"
        case .water:
            content.title = "💧 Water Reminder"
            content.body = "Don't forget to stay hydrated!"
            prefix = "water_progress"
        case .protein:
            content.title = "🥩 Protein Check"
            content.body = "Track your protein intake today!"
            prefix = "protein_progress"
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        guard let hour = components.hour, let minute = components.minute else {
            return
        }

        var dailyComponents = DateComponents()
        dailyComponents.hour = hour
        dailyComponents.minute = minute
        dailyComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dailyComponents, repeats: true)
        let identifier = "\(prefix)_\(hour)_\(minute)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func clearNotifications(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { identifier in
                    identifier.identifier.hasPrefix(prefix)
                }
                .map { $0.identifier }
            
            if !identifiersToRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            }
        }
    }
    
    
    private func scheduleNotificationForTime(time: Date, identifier: String, content: UNMutableNotificationContent, index: Int, type: String) {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the hour and minute from the selected time
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else {
            return
        }
        
        // Create date components for today at the specified time
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = hour
        todayComponents.minute = minute
        todayComponents.second = 0
        
        // Get the date for today at the specified time
        guard let todayAtTime = calendar.date(from: todayComponents) else {
            return
        }
        
        // If the time has already passed today, schedule for tomorrow
        let targetDate = todayAtTime < now ? calendar.date(byAdding: .day, value: 1, to: todayAtTime)! : todayAtTime
        
        // Only schedule the repeating daily notification to avoid duplicates
        var dailyComponents = DateComponents()
        dailyComponents.hour = hour
        dailyComponents.minute = minute
        dailyComponents.second = 0
        
        let dailyTrigger = UNCalendarNotificationTrigger(dateMatching: dailyComponents, repeats: true)
        let dailyRequest = UNNotificationRequest(identifier: identifier, content: content, trigger: dailyTrigger)
        
        UNUserNotificationCenter.current().add(dailyRequest) { error in
            // Silently handle any errors
        }
    }
    
    // Handle notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // MARK: - Progress Message Functions
    
    @MainActor
    private func getCalorieProgressMessage() async -> String {
        do {
            // Get current goal data
            let dataService = DataService.shared
            guard let goal = try await dataService.fetchActiveGoal() else {
                return "Set your daily calorie goal to track your progress!"
            }
            
            // Calculate daily goal adjustment like in GoalViewModel
            // Based on calculated weekly weight change from target and current weight
            let weeklyChange = await calculateWeeklyChange(for: goal)
            let dailyGoalAdjustment = (weeklyChange * 7700) / 7
            
            // Calculate current balance like in NutritionDashboardView
            let healthKitService = HealthKitService()
            let today = Date()
            
            // Get consumed calories from nutrition data
            let nutrition = try? await dataService.fetchDailyNutrition(for: today)
            let consumed = nutrition?.totalCalories ?? 0
            
            // Get energy burned (same as CalorieBalanceService)
            let restingEnergy = (try? await healthKitService.fetchRestingEnergy(for: today)) ?? 1800.0
            let activeEnergy = (try? await healthKitService.fetchActiveEnergy(for: today)) ?? (restingEnergy * 0.2)
            let totalBurned = restingEnergy + activeEnergy
            
            // Calculate balance: consumed - burned
            let currentBalance = consumed - totalBurned
            
            // Format like NutritionDashboardView: current balance vs daily goal adjustment
            let currentSign = currentBalance >= 0 ? "+" : ""
            let goalSign = dailyGoalAdjustment >= 0 ? "+" : ""
            
            return "Your balance is \(currentSign)\(Int(currentBalance)) kcal vs goal of \(goalSign)\(Int(dailyGoalAdjustment)) kcal"
            
        } catch {
            return "Check your calorie balance toward your daily goal!"
        }
    }
    
    @MainActor
    private func getWaterProgressMessage() async -> String {
        let dataManager = AppDataManager.shared
        await dataManager.loadInitialData()
        
        let consumed = dataManager.waterConsumed
        let target = dataManager.waterTarget
        let remaining = target - consumed
        
        if remaining > 0 {
            return "You've had \(Int(consumed))ml of water today. \(Int(remaining))ml remaining to reach your \(Int(target))ml goal!"
        } else {
            return "Great job! You've reached your daily water goal of \(Int(target))ml. Keep staying hydrated!"
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateWeeklyChange(for goal: FitnessGoal) async -> Double {
        guard let targetWeight = goal.targetWeight,
              goal.type != .maintainWeight else {
            return 0
        }
        
        // Get current weight from user data
        let dataService = DataService.shared
        guard let user = try? await dataService.fetchUser(),
              let targetDate = goal.targetDate else {
            return goal.weeklyWeightChangeGoal // fallback to stored value
        }
        
        let currentWeight = user.weight
        let weightDifference = targetWeight - currentWeight
        let weeksToTarget = targetDate.timeIntervalSince(Date()) / (7 * 24 * 60 * 60)
        
        guard weeksToTarget > 0 else { return 0 }
        
        return weightDifference / weeksToTarget
    }
}
