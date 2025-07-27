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
        
        for (index, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "🔥 Calorie Check-in"
            content.body = "How are you doing with your daily calorie goal?"
            content.sound = .default
            content.categoryIdentifier = "FITNESS_PROGRESS"
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "calorie_progress_\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func scheduleWaterProgressNotifications(times: [Date], enabled: Bool) {
        clearNotifications(withPrefix: "water_progress")
        
        guard enabled else { return }
        
        for (index, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "💧 Hydration Reminder"
            content.body = "Time to check your water intake! Stay hydrated!"
            content.sound = .default
            content.categoryIdentifier = "FITNESS_PROGRESS"
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "water_progress_\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func scheduleProteinProgressNotifications(times: [Date], enabled: Bool) {
        clearNotifications(withPrefix: "protein_progress")
        
        guard enabled else { return }
        
        for (index, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "🥩 Protein Check"
            content.body = "Don't forget to track your protein intake today!"
            content.sound = .default
            content.categoryIdentifier = "FITNESS_PROGRESS"
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "protein_progress_\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func clearAllProgressNotifications() {
        clearNotifications(withPrefix: "calorie_progress")
        clearNotifications(withPrefix: "water_progress")
        clearNotifications(withPrefix: "protein_progress")
    }
    
    private func clearNotifications(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
    
    // Handle notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
