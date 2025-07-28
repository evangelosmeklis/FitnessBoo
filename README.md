# FitnessBoo 🏃‍♂️💪

A comprehensive iOS fitness tracking app built with SwiftUI that helps you monitor your nutrition, set fitness goals, and track your progress toward a healthier lifestyle.

## ✨ Features

### 🍎 Nutrition Tracking
- Log daily food intake with detailed nutritional information
- Track calories, proteins, carbs, and fats
- Visual progress indicators for daily targets
- Smart calorie balance calculations

### 🎯 Goal Management
- Set personalized weight loss, weight gain, or maintenance goals
- Dynamic daily calorie adjustments based on progress
- Target date tracking with intelligent weekly change calculations
- Real-time goal validation and recommendations

### 📊 Progress Monitoring
- Comprehensive dashboard with at-a-glance metrics
- Historical data visualization
- Energy breakdown and expenditure tracking
- Progress charts and trends

### 💧 Hydration Tracking
- Daily water intake monitoring
- Customizable hydration goals
- Progress notifications and reminders

### 🔔 Smart Notifications
- Daily progress updates
- Calorie balance notifications
- Hydration reminders
- Goal achievement celebrations

### ⚡ Health Integration
- Seamless HealthKit integration
- Automatic energy expenditure tracking
- Resting and active energy monitoring
- Weight data synchronization

## 🏗️ Architecture

FitnessBoo follows the MVVM (Model-View-ViewModel) architecture pattern with SwiftUI, ensuring clean separation of concerns and maintainability.

### Core Components

- **Models**: Data structures for User, FitnessGoal, DailyNutrition, FoodEntry, and more
- **Services**: Business logic for data management, calculations, HealthKit integration, and notifications
- **ViewModels**: State management and business logic coordination
- **Views**: SwiftUI user interface components with modern design

### Key Services

- `DataService`: Core Data persistence and data management
- `HealthKitService`: Integration with Apple HealthKit
- `CalculationService`: Fitness calculations and goal validation
- `NotificationService`: Smart notification delivery
- `CalorieBalanceService`: Real-time calorie balance tracking

## 🚀 Getting Started

### Prerequisites

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

### Setup

1. Clone the repository
2. Open `FitnessBoo.xcodeproj` in Xcode
3. Build and run the project
4. Grant HealthKit permissions when prompted
5. Complete the onboarding process

## 🧪 Testing

The project includes comprehensive test coverage:

- **Unit Tests**: Model validation, service logic, and calculation accuracy
- **UI Tests**: User flow validation and interface testing
- **Mock Services**: Isolated testing with mock data providers

Run tests using `⌘+U` in Xcode or via the command line.

## 📱 Key Screens

- **Dashboard**: Overview of daily progress and quick actions
- **Nutrition**: Detailed food logging and nutritional breakdown
- **Goals**: Fitness goal setup and progress tracking
- **History**: Historical data and progress visualization
- **Settings**: App configuration and user preferences

## 🎨 Design

FitnessBoo features a modern, clean interface with:
- Glass morphism design elements
- Intuitive navigation with custom tab bar
- Responsive layouts for all device sizes
- Accessibility-first approach

## 🔒 Privacy

Your health data stays on your device. FitnessBoo uses HealthKit for secure data access and Core Data for local storage, ensuring your personal information remains private.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Built with ❤️ using SwiftUI and HealthKit*