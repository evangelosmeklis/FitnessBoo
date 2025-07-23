# Design Document

## Overview

The FitnessBoo app will be built using SwiftUI with iOS 17+ as the minimum deployment target to leverage the latest HealthKit capabilities and modern UI components. The architecture follows MVVM (Model-View-ViewModel) pattern with a clean separation of concerns, utilizing Combine for reactive programming and Core Data for local persistence. The app integrates deeply with Apple's HealthKit framework to provide seamless data synchronization with the Health and Fitness apps.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI Views │    │   ViewModels    │    │     Models      │
│                 │◄──►│                 │◄──►│                 │
│ - Onboarding    │    │ - UserProfile   │    │ - User          │
│ - Dashboard     │    │ - Nutrition     │    │ - FoodEntry     │
│ - History       │    │ - Workout       │    │ - WorkoutData   │
│ - Settings      │    │ - Goals         │    │ - DailyStats    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
┌─────────────────────────────────┼─────────────────────────────────┐
│                    Services Layer                                  │
├─────────────────┬───────────────┬───────────────┬─────────────────┤
│  HealthKit      │  Core Data    │  Notification │  Calculation    │
│  Service        │  Service      │  Service      │  Service        │
│                 │               │               │                 │
│ - Data sync     │ - Local       │ - Push        │ - BMR           │
│ - Permissions   │   storage     │   notifications│ - Calorie       │
│ - Workout data  │ - Persistence │ - Scheduling  │   targets       │
└─────────────────┴───────────────┴───────────────┴─────────────────┘
```

### Design Patterns

- **MVVM**: Clear separation between UI, business logic, and data
- **Repository Pattern**: Abstracted data access layer
- **Observer Pattern**: Using Combine for reactive updates
- **Singleton Pattern**: For shared services (HealthKit, Notifications)
- **Factory Pattern**: For creating different goal calculation strategies

## Components and Interfaces

### Core Models

#### User Model
```swift
struct User: Codable, Identifiable {
    let id: UUID
    var age: Int
    var weight: Double
    var height: Double
    var gender: Gender
    var activityLevel: ActivityLevel
    var preferredUnits: UnitSystem
    var bmr: Double
    var createdAt: Date
    var updatedAt: Date
}

enum Gender: String, CaseIterable, Codable {
    case male, female, other
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary, lightlyActive, moderatelyActive, veryActive, extremelyActive
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }
}
```

#### Goal Model
```swift
struct FitnessGoal: Codable, Identifiable {
    let id: UUID
    var type: GoalType
    var targetWeight: Double?
    var targetDate: Date?
    var weeklyWeightChangeGoal: Double
    var dailyCalorieTarget: Double
    var dailyProteinTarget: Double
    var isActive: Bool
}

enum GoalType: String, CaseIterable, Codable {
    case loseWeight, maintainWeight, gainWeight, gainMuscle
}
```

#### Nutrition Models
```swift
struct FoodEntry: Codable, Identifiable {
    let id: UUID
    var calories: Double
    var protein: Double?
    var timestamp: Date
    var mealType: MealType?
    var notes: String?
}

enum MealType: String, CaseIterable, Codable {
    case breakfast, lunch, dinner, snack
}

struct DailyNutrition: Codable {
    let date: Date
    var totalCalories: Double
    var totalProtein: Double
    var entries: [FoodEntry]
    var calorieTarget: Double
    var proteinTarget: Double
}
```

### Service Interfaces

#### HealthKit Service
```swift
protocol HealthKitServiceProtocol {
    func requestAuthorization() async throws
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutData]
    func fetchActiveEnergy(for date: Date) async throws -> Double
    func fetchWeight() async throws -> Double?
    func observeWeightChanges() -> AnyPublisher<Double, Never>
    func observeWorkouts() -> AnyPublisher<[WorkoutData], Never>
}
```

#### Data Persistence Service
```swift
protocol DataServiceProtocol {
    func saveUser(_ user: User) async throws
    func fetchUser() async throws -> User?
    func saveFoodEntry(_ entry: FoodEntry) async throws
    func fetchFoodEntries(for date: Date) async throws -> [FoodEntry]
    func saveDailyStats(_ stats: DailyStats) async throws
    func fetchDailyStats(for dateRange: ClosedRange<Date>) async throws -> [DailyStats]
}
```

### View Architecture

#### Navigation Structure
```
TabView
├── Dashboard Tab
│   ├── DashboardView
│   ├── QuickLogView (Sheet)
│   └── GoalProgressView
├── History Tab
│   ├── HistoryListView
│   ├── DayDetailView
│   └── ChartsView
├── Goals Tab
│   ├── GoalSettingView
│   └── GoalProgressView
└── Settings Tab
    ├── SettingsView
    ├── UnitsPreferenceView
    ├── NotificationSettingsView
    └── ProfileEditView
```

#### Key ViewModels

```swift
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dailyStats: DailyStats?
    @Published var calorieProgress: Double = 0
    @Published var proteinProgress: Double = 0
    @Published var isLoading = false
    
    private let healthKitService: HealthKitServiceProtocol
    private let dataService: DataServiceProtocol
    private let calculationService: CalculationServiceProtocol
}

@MainActor
class NutritionViewModel: ObservableObject {
    @Published var foodEntries: [FoodEntry] = []
    @Published var dailyTotals: DailyNutrition?
    @Published var showingAddFood = false
    
    func addFoodEntry(_ entry: FoodEntry) async
    func deleteFoodEntry(_ entry: FoodEntry) async
    func updateDailyTotals() async
}
```

## Data Models

### Core Data Schema

#### UserEntity
- id: UUID (Primary Key)
- age: Int16
- weight: Double
- height: Double
- gender: String
- activityLevel: String
- preferredUnits: String
- bmr: Double
- createdAt: Date
- updatedAt: Date

#### FoodEntryEntity
- id: UUID (Primary Key)
- calories: Double
- protein: Double (Optional)
- timestamp: Date
- mealType: String (Optional)
- notes: String (Optional)
- user: UserEntity (Relationship)

#### DailyStatsEntity
- id: UUID (Primary Key)
- date: Date
- totalCaloriesConsumed: Double
- totalProtein: Double
- caloriesFromExercise: Double
- netCalories: Double
- weightRecorded: Double (Optional)
- user: UserEntity (Relationship)

#### GoalEntity
- id: UUID (Primary Key)
- type: String
- targetWeight: Double (Optional)
- targetDate: Date (Optional)
- weeklyWeightChangeGoal: Double
- dailyCalorieTarget: Double
- dailyProteinTarget: Double
- isActive: Bool
- user: UserEntity (Relationship)

### HealthKit Data Types

The app will request access to the following HealthKit data types:

**Read Permissions:**
- HKQuantityType.quantityType(forIdentifier: .bodyMass)
- HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
- HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
- HKObjectType.workoutType()

**Write Permissions:**
- HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
- HKQuantityType.quantityType(forIdentifier: .dietaryProtein)

## Error Handling

### Error Types
```swift
enum AppError: LocalizedError {
    case healthKitNotAvailable
    case healthKitPermissionDenied
    case dataCorruption
    case networkError
    case invalidUserInput(String)
    case calculationError
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .healthKitPermissionDenied:
            return "Health data access is required for full functionality"
        case .dataCorruption:
            return "Data corruption detected. Please restart the app"
        case .networkError:
            return "Network connection required"
        case .invalidUserInput(let message):
            return message
        case .calculationError:
            return "Unable to calculate nutrition targets"
        }
    }
}
```

### Error Handling Strategy
- **Graceful Degradation**: App functions with limited features if HealthKit access is denied
- **User-Friendly Messages**: All errors presented with clear, actionable messages
- **Retry Mechanisms**: Automatic retry for network and sync operations
- **Fallback Options**: Manual data entry when automatic sync fails
- **Error Logging**: Comprehensive logging for debugging without exposing sensitive data

## Testing Strategy

### Unit Testing
- **Model Tests**: Validation logic, calculation accuracy, data transformations
- **Service Tests**: Mock HealthKit responses, Core Data operations, calculation services
- **ViewModel Tests**: Business logic, state management, user interactions
- **Utility Tests**: BMR calculations, unit conversions, date handling

### Integration Testing
- **HealthKit Integration**: Real device testing with actual health data
- **Core Data Integration**: Database operations, migrations, relationships
- **Notification Testing**: Local notification scheduling and delivery
- **Cross-Service Testing**: Data flow between services

### UI Testing
- **Onboarding Flow**: Complete user setup process
- **Data Entry**: Food logging, goal setting, profile updates
- **Navigation**: Tab switching, modal presentations, deep linking
- **Accessibility**: VoiceOver support, dynamic type, high contrast

### Performance Testing
- **Memory Usage**: Large dataset handling, image caching
- **Battery Impact**: Background sync, location services
- **Startup Time**: App launch performance, data loading
- **Sync Performance**: HealthKit data synchronization speed

### Test Data Strategy
- **Mock Health Data**: Simulated workout and weight data for testing
- **Edge Cases**: Extreme values, missing data, corrupted entries
- **Localization Testing**: Different languages, number formats, date formats
- **Device Testing**: Various screen sizes, iOS versions, hardware capabilities

### Continuous Integration
- **Automated Testing**: Unit and integration tests on every commit
- **Code Coverage**: Minimum 80% coverage requirement
- **Static Analysis**: SwiftLint for code quality, security scanning
- **Performance Monitoring**: Automated performance regression detection

## Security and Privacy

### Data Protection
- **Local Encryption**: Core Data encrypted at rest
- **Keychain Storage**: Sensitive user preferences stored securely
- **No Cloud Storage**: All data remains on device unless explicitly shared
- **HealthKit Privacy**: Follows Apple's strict HealthKit privacy guidelines

### Privacy Compliance
- **Minimal Data Collection**: Only collect data necessary for functionality
- **User Consent**: Clear permission requests with explanations
- **Data Retention**: Automatic cleanup of old data based on user preferences
- **Export Options**: Allow users to export their data