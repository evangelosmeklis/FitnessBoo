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
    
    // Handle notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
