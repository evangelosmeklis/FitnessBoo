//
//  LiquidGlassTabBar.swift
//  FitnessBoo
//
//  Created by Kiro on 27/7/25.
//

import SwiftUI

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == index,
                    action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedTab = index
                        }
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(liquidGlassBackground)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var liquidGlassBackground: some View {
        ZStack {
            // Base glass layer
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
            
            // Liquid glass overlay with dynamic gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.black.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Border highlight
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                
                Text(tab.title)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .frame(height: 50)
        }
        .buttonStyle(TabButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}

struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TabItem {
    let title: String
    let icon: String
    let selectedIcon: String
    
    init(title: String, icon: String, selectedIcon: String? = nil) {
        self.title = title
        self.icon = icon
        self.selectedIcon = selectedIcon ?? icon
    }
}

// MARK: - Main Tab Container

struct LiquidGlassTabView<Content: View>: View {
    @State private var selectedTab = 0
    let content: Content
    let tabs: [TabItem]
    
    init(tabs: [TabItem], @ViewBuilder content: () -> Content) {
        self.tabs = tabs
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating liquid glass tab bar
            LiquidGlassTabBar(selectedTab: $selectedTab, tabs: tabs)
                .zIndex(1)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Enhanced Tab Container with Page Management

struct LiquidGlassTabContainer: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dataManager = AppDataManager.shared
    @State private var selectedTab = 0
    @State private var hasRequestedHealthKit = false
    
    // Service dependencies
    private let healthKitService: HealthKitServiceProtocol = HealthKitService()
    private let dataService: DataServiceProtocol = DataService.shared
    private let calculationService: CalculationServiceProtocol = CalculationService()
    
    private let tabs = [
        TabItem(title: "Dashboard", icon: "house", selectedIcon: "house.fill"),
        TabItem(title: "Nutrition", icon: "chart.bar", selectedIcon: "chart.bar.fill"),
        TabItem(title: "Goals", icon: "target"),
        TabItem(title: "Settings", icon: "gearshape", selectedIcon: "gearshape.fill")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content pages
            TabView(selection: $selectedTab) {
                DashboardView(
                    healthKitService: healthKitService,
                    dataService: dataService,
                    calculationService: calculationService
                )
                .tag(0)
                
                NutritionDashboardView(
                    dataService: dataService,
                    calculationService: calculationService,
                    healthKitService: healthKitService
                )
                .tag(1)
                
                GoalSettingView(
                    calculationService: calculationService,
                    dataService: dataService,
                    healthKitService: healthKitService
                )
                .tag(2)
                
                SettingsView(
                    calculationService: calculationService,
                    dataService: dataService,
                    healthKitService: healthKitService
                )
                .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea(.all, edges: .bottom)
            
            // Custom floating liquid glass tab bar
            LiquidGlassTabBar(selectedTab: $selectedTab, tabs: tabs)
                .zIndex(1)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            requestHealthKitAuthorizationIfNeeded()
        }
        .task {
            await dataManager.loadInitialData()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func requestHealthKitAuthorizationIfNeeded() {
        guard !hasRequestedHealthKit else { return }
        hasRequestedHealthKit = true
        
        Task {
            do {
                try await healthKitService.requestAuthorization()
                print("HealthKit authorization completed successfully")
                
                // Create user profile if it doesn't exist
                if try await dataService.fetchUser() == nil {
                    let user = try await dataService.createUserFromHealthKit(healthKitService: healthKitService)
                    print("User profile created from HealthKit data: \(user)")
                }
                
                // Also request notification permissions
                try await NotificationService.shared.requestAuthorization()
                print("Notification authorization completed successfully")
                
            } catch {
                print("Authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - refresh HealthKit data
            refreshHealthKitData()
            // Check if the day has changed
            checkForDayChange()
        case .inactive:
            // App became inactive - could pause background sync if needed
            break
        case .background:
            // App went to background - background sync will continue
            break
        @unknown default:
            break
        }
    }
    
    private func refreshHealthKitData() {
        Task {
            do {
                // Trigger manual refresh of HealthKit data
                try await healthKitService.manualRefresh()
                print("HealthKit data refreshed successfully")
            } catch {
                print("HealthKit data refresh failed: \(error.localizedDescription)")
                // Continue silently - background sync will retry
            }
        }
    }
    
    private func checkForDayChange() {
        let lastOpened = UserDefaults.standard.object(forKey: "lastOpenedDate") as? Date ?? Date()
        if !Calendar.current.isDateInToday(lastOpened) {
            // Day has changed, reset metrics
            NotificationCenter.default.post(name: NSNotification.Name("DayChanged"), object: nil)
        }
        UserDefaults.standard.set(Date(), forKey: "lastOpenedDate")
    }
}

// MARK: - Preview

struct LiquidGlassTabBar_Previews: PreviewProvider {
    static var previews: some View {
        LiquidGlassTabContainer()
            .preferredColorScheme(.light)
        
        LiquidGlassTabContainer()
            .preferredColorScheme(.dark)
    }
}