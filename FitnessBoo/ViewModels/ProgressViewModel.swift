//
//  ProgressViewModel.swift
//  FitnessBoo
//
//  Created by Kiro on 24/7/25.
//

import Foundation
import Combine

struct DailyProgressData {
    let date: Date
    let dailyBalance: Double
    let cumulativeBalance: Double
    let targetCumulativeBalance: Double
}

@MainActor
class ProgressViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var weeklyCalorieBalance: Double = 0
    @Published var weeklyTargetCalorieBalance: Double = 0
    @Published var totalCalorieBalance: Double = 0
    @Published var totalTargetCalorieBalance: Double = 0
    @Published var currentWeekNumber: Int = 1
    @Published var daysRemainingToGoal: Int?
    @Published var overallProgressPercentage: Double = 0
    @Published var isOnTrackWeekly: Bool = false
    @Published var isOnTrackOverall: Bool = false
    @Published var weeklyProgressStatus: String = ""
    @Published var weeklyProgressDetails: String = ""
    @Published var overallProgressStatus: String = ""
    @Published var overallProgressDetails: String = ""
    @Published var insights: [String] = []
    @Published var dailyProgressData: [DailyProgressData] = []
    @Published var isLoading = false
    
    // MARK: - Dependencies
    private let dataService: DataServiceProtocol
    private let calculationService: CalculationServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let calorieBalanceService: CalorieBalanceService
    
    // MARK: - Private Properties
    private var currentGoal: FitnessGoal?
    private var goalStartDate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(dataService: DataServiceProtocol, calculationService: CalculationServiceProtocol, healthKitService: HealthKitServiceProtocol) {
        self.dataService = dataService
        self.calculationService = calculationService
        self.healthKitService = healthKitService
        self.calorieBalanceService = CalorieBalanceService(
            healthKitService: healthKitService,
            calculationService: calculationService,
            dataService: dataService
        )
    }
    
    // MARK: - Public Methods
    
    func loadProgressData() async {
        isLoading = true
        
        do {
            // Load current goal
            currentGoal = try await dataService.fetchActiveGoal()
            
            guard let goal = currentGoal else {
                // No active goal
                resetProgressData()
                isLoading = false
                return
            }
            
            // Calculate goal start date (when goal was created or updated)
            goalStartDate = goal.createdAt
            
            // Calculate progress
            await calculateWeeklyProgress()
            await calculateOverallProgress()
            await generateDailyProgressData()
            generateInsights()
            
        } catch {
            print("Error loading progress data: \(error)")
            resetProgressData()
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadProgressData()
    }
    
    // MARK: - Private Methods
    
    private func resetProgressData() {
        weeklyCalorieBalance = 0
        weeklyTargetCalorieBalance = 0
        totalCalorieBalance = 0
        totalTargetCalorieBalance = 0
        currentWeekNumber = 1
        daysRemainingToGoal = nil
        overallProgressPercentage = 0
        isOnTrackWeekly = false
        isOnTrackOverall = false
        weeklyProgressStatus = "No active goal"
        weeklyProgressDetails = "Set a goal to track your progress"
        overallProgressStatus = "No active goal"
        overallProgressDetails = "Set a goal to track your progress"
        insights = ["Set a fitness goal to start tracking your progress!"]
        dailyProgressData = []
    }
    
    private func calculateWeeklyProgress() async {
        guard let goal = currentGoal, let startDate = goalStartDate else { return }
        
        // Get current week start (Monday)
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7 // Convert Sunday=1 to Monday=0
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        
        // Calculate which week we're in since goal started
        let weeksFromStart = currentWeekStart.timeIntervalSince(startDate)
        currentWeekNumber = max(1, Int(weeksFromStart / (7 * 24 * 60 * 60)) + 1)
        
        // Calculate weekly target (daily target × 7)
        let dailyTarget = calculateDailyCalorieTarget(for: goal)
        weeklyTargetCalorieBalance = dailyTarget * 7
        
        // Calculate actual weekly balance
        weeklyCalorieBalance = 0
        for dayOffset in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart),
               dayDate <= today {
                if let balance = await calorieBalanceService.getBalanceForDate(dayDate) {
                    weeklyCalorieBalance += balance.balance
                }
            }
        }
        
        // Determine if on track
        let tolerance = abs(weeklyTargetCalorieBalance) * 0.1 // 10% tolerance
        isOnTrackWeekly = abs(weeklyCalorieBalance - weeklyTargetCalorieBalance) <= tolerance
        
        // Generate status messages
        generateWeeklyStatusMessages()
    }
    
    private func calculateOverallProgress() async {
        guard let goal = currentGoal, let startDate = goalStartDate else { return }
        
        let today = Date()
        let calendar = Calendar.current
        
        // Calculate days since goal started
        let daysSinceStart = today.timeIntervalSince(startDate)
        let daysElapsed = Int(daysSinceStart / (24 * 60 * 60))
        
        // Calculate total days to goal
        let totalDaysToGoal: Int
        if let targetDate = goal.targetDate {
            let totalDuration = targetDate.timeIntervalSince(startDate)
            totalDaysToGoal = Int(totalDuration / (24 * 60 * 60))
            let remaining = targetDate.timeIntervalSince(today)
            daysRemainingToGoal = max(0, Int(remaining / (24 * 60 * 60)))
        } else {
            // Estimate based on weight change goal
            if let targetWeight = goal.targetWeight,
               let currentWeight = try? await healthKitService.fetchWeight() {
                let weightToLose = abs(targetWeight - currentWeight)
                let weeksNeeded = weightToLose / abs(goal.weeklyWeightChangeGoal)
                totalDaysToGoal = Int(weeksNeeded * 7.0)
                daysRemainingToGoal = max(0, totalDaysToGoal - daysElapsed)
            } else {
                totalDaysToGoal = 84 // Default 12 weeks
                daysRemainingToGoal = max(0, totalDaysToGoal - daysElapsed)
            }
        }
        
        // Calculate daily target
        let dailyTarget = calculateDailyCalorieTarget(for: goal)
        
        // Calculate total target balance
        totalTargetCalorieBalance = dailyTarget * Double(daysElapsed)
        
        // Calculate actual total balance
        totalCalorieBalance = 0
        for dayOffset in 0..<daysElapsed {
            if let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                if let balance = await calorieBalanceService.getBalanceForDate(dayDate) {
                    totalCalorieBalance += balance.balance
                }
            }
        }
        
        // Calculate progress percentage
        if totalTargetCalorieBalance != 0 {
            overallProgressPercentage = min(1.0, abs(totalCalorieBalance) / abs(totalTargetCalorieBalance))
        } else {
            overallProgressPercentage = 0
        }
        
        // Determine if on track overall
        let tolerance = abs(totalTargetCalorieBalance) * 0.15 // 15% tolerance for overall
        isOnTrackOverall = abs(totalCalorieBalance - totalTargetCalorieBalance) <= tolerance
        
        // Generate status messages
        generateOverallStatusMessages()
    }
    
    private func generateDailyProgressData() async {
        guard let goal = currentGoal, let startDate = goalStartDate else { return }
        
        let calendar = Calendar.current
        let today = Date()
        let daysSinceStart = today.timeIntervalSince(startDate)
        let daysElapsed = min(30, Int(daysSinceStart / (24 * 60 * 60))) // Show last 30 days max
        
        let dailyTarget = calculateDailyCalorieTarget(for: goal)
        var cumulativeBalance: Double = 0
        var data: [DailyProgressData] = []
        
        for dayOffset in (0..<daysElapsed).reversed() {
            if let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dailyBalance: Double
                if let balance = await calorieBalanceService.getBalanceForDate(dayDate) {
                    dailyBalance = balance.balance
                } else {
                    dailyBalance = 0
                }
                
                cumulativeBalance += dailyBalance
                let targetCumulative = dailyTarget * Double(daysElapsed - dayOffset)
                
                data.append(DailyProgressData(
                    date: dayDate,
                    dailyBalance: dailyBalance,
                    cumulativeBalance: cumulativeBalance,
                    targetCumulativeBalance: targetCumulative
                ))
            }
        }
        
        dailyProgressData = data
    }
    
    private func calculateDailyCalorieTarget(for goal: FitnessGoal) -> Double {
        // Calculate daily calorie adjustment needed
        guard let targetWeight = goal.targetWeight else {
            return goal.weeklyWeightChangeGoal * 7700 / 7 // 7700 cal per kg
        }
        
        // Use the goal's weekly change to calculate daily target
        return goal.weeklyWeightChangeGoal * 7700 / 7 // 7700 calories per kg of fat
    }
    
    private func generateWeeklyStatusMessages() {
        let difference = weeklyCalorieBalance - weeklyTargetCalorieBalance
        let absDifference = abs(difference)
        
        if isOnTrackWeekly {
            weeklyProgressStatus = "On Track!"
            weeklyProgressDetails = "You're doing great this week. Keep it up!"
        } else if weeklyTargetCalorieBalance < 0 { // Weight loss goal
            if weeklyCalorieBalance > weeklyTargetCalorieBalance {
                weeklyProgressStatus = "Behind Target"
                weeklyProgressDetails = "Need \(Int(absDifference)) more calorie deficit this week"
            } else {
                weeklyProgressStatus = "Ahead of Target"
                weeklyProgressDetails = "You're \(Int(absDifference)) calories ahead this week!"
            }
        } else { // Weight gain goal
            if weeklyCalorieBalance < weeklyTargetCalorieBalance {
                weeklyProgressStatus = "Behind Target"
                weeklyProgressDetails = "Need \(Int(absDifference)) more calorie surplus this week"
            } else {
                weeklyProgressStatus = "Ahead of Target"
                weeklyProgressDetails = "You're \(Int(absDifference)) calories ahead this week!"
            }
        }
    }
    
    private func generateOverallStatusMessages() {
        let difference = totalCalorieBalance - totalTargetCalorieBalance
        let absDifference = abs(difference)
        
        if isOnTrackOverall {
            overallProgressStatus = "On Track!"
            overallProgressDetails = "You're making excellent progress towards your goal."
        } else if totalTargetCalorieBalance < 0 { // Weight loss goal
            if totalCalorieBalance > totalTargetCalorieBalance {
                overallProgressStatus = "Behind Target"
                overallProgressDetails = "You need to increase your deficit by \(Int(absDifference)) calories to catch up to your goal."
            } else {
                overallProgressStatus = "Ahead of Target"
                overallProgressDetails = "Excellent! You're \(Int(absDifference)) calories ahead of your target."
            }
        } else { // Weight gain goal
            if totalCalorieBalance < totalTargetCalorieBalance {
                overallProgressStatus = "Behind Target"
                overallProgressDetails = "You need to increase your surplus by \(Int(absDifference)) calories to catch up to your goal."
            } else {
                overallProgressStatus = "Ahead of Target"
                overallProgressDetails = "Great! You're \(Int(absDifference)) calories ahead of your target."
            }
        }
    }
    
    private func generateInsights() {
        var newInsights: [String] = []
        
        // Weekly insights
        if !isOnTrackWeekly {
            if weeklyTargetCalorieBalance < 0 {
                newInsights.append("Try increasing your daily activity or reducing portion sizes to meet your weekly deficit goal.")
            } else {
                newInsights.append("Consider adding healthy snacks or increasing meal portions to meet your weekly surplus goal.")
            }
        }
        
        // Overall progress insights
        if overallProgressPercentage < 0.5 && daysRemainingToGoal != nil {
            newInsights.append("You're in the early stages of your goal. Stay consistent with your daily habits.")
        } else if overallProgressPercentage > 0.8 {
            newInsights.append("You're close to your goal! Maintain your current approach.")
        }
        
        // Trend insights
        if dailyProgressData.count >= 7 {
            let recentAverage = dailyProgressData.suffix(7).map { $0.dailyBalance }.reduce(0, +) / 7
            let targetDaily = weeklyTargetCalorieBalance / 7.0
            
            if abs(recentAverage - targetDaily) > abs(targetDaily) * 0.2 {
                newInsights.append("Your recent daily average is off target. Consider adjusting your daily routine.")
            }
        }
        
        // Default insight if none generated
        if newInsights.isEmpty {
            newInsights.append("Keep tracking your daily nutrition and stay consistent with your goals!")
        }
        
        insights = newInsights
    }
}