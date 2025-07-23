//
//  OnboardingUITests.swift
//  FitnessBooUITests
//
//  Created by Kiro on 23/7/25.
//

import XCTest

final class OnboardingUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testCompleteOnboardingFlow() throws {
        // Step 1: Welcome screen
        XCTAssertTrue(app.staticTexts["Welcome to FitnessBoo!"].exists)
        XCTAssertTrue(app.staticTexts["Step 1 of 5"].exists)
        
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.exists)
        nextButton.tap()
        
        // Step 2: Basic Information
        XCTAssertTrue(app.staticTexts["Basic Information"].exists)
        XCTAssertTrue(app.staticTexts["Step 2 of 5"].exists)
        
        // Test age input
        let ageField = app.textFields["Enter your age"]
        XCTAssertTrue(ageField.exists)
        ageField.tap()
        ageField.typeText("25")
        
        // Test gender selection
        let genderPicker = app.segmentedControls.element(boundBy: 0)
        XCTAssertTrue(genderPicker.exists)
        genderPicker.buttons["Female"].tap()
        
        // Test units selection
        let unitsPicker = app.segmentedControls.element(boundBy: 1)
        XCTAssertTrue(unitsPicker.exists)
        unitsPicker.buttons["Imperial"].tap()
        
        nextButton.tap()
        
        // Step 3: Physical Information
        XCTAssertTrue(app.staticTexts["Physical Information"].exists)
        XCTAssertTrue(app.staticTexts["Step 3 of 5"].exists)
        
        // Test weight input
        let weightField = app.textFields["Enter your weight"]
        XCTAssertTrue(weightField.exists)
        weightField.tap()
        weightField.typeText("140")
        
        // Test height input
        let heightField = app.textFields["Enter your height"]
        XCTAssertTrue(heightField.exists)
        heightField.tap()
        heightField.typeText("65")
        
        nextButton.tap()
        
        // Step 4: Activity Level
        XCTAssertTrue(app.staticTexts["Activity Level"].exists)
        XCTAssertTrue(app.staticTexts["Step 4 of 5"].exists)
        
        // Select activity level
        let moderatelyActiveButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Moderately Active'")).element
        XCTAssertTrue(moderatelyActiveButton.exists)
        moderatelyActiveButton.tap()
        
        nextButton.tap()
        
        // Step 5: Review
        XCTAssertTrue(app.staticTexts["Review Your Information"].exists)
        XCTAssertTrue(app.staticTexts["Step 5 of 5"].exists)
        
        // Verify review information
        XCTAssertTrue(app.staticTexts["25 years"].exists)
        XCTAssertTrue(app.staticTexts["Female"].exists)
        XCTAssertTrue(app.staticTexts["140 lbs"].exists)
        XCTAssertTrue(app.staticTexts["65 inches"].exists)
        XCTAssertTrue(app.staticTexts["Moderately Active"].exists)
        XCTAssertTrue(app.staticTexts["Imperial"].exists)
        
        // Complete setup
        let completeButton = app.buttons["Complete Setup"]
        XCTAssertTrue(completeButton.exists)
        completeButton.tap()
        
        // Verify completion (dashboard should appear)
        XCTAssertTrue(app.staticTexts["Dashboard - Setup Complete!"].waitForExistence(timeout: 5))
    }
    
    func testAgeValidation() throws {
        // Navigate to basic info step
        app.buttons["Next"].tap()
        
        let ageField = app.textFields["Enter your age"]
        let nextButton = app.buttons["Next"]
        
        // Test empty age
        XCTAssertFalse(nextButton.isEnabled)
        
        // Test invalid age (too high)
        ageField.tap()
        ageField.typeText("200")
        
        // Try to proceed - should show error
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Age must be between 1 and 149 years"].exists)
        
        // Clear and enter valid age
        ageField.clearAndEnterText("25")
        XCTAssertFalse(app.staticTexts["Age must be between 1 and 149 years"].exists)
    }
    
    func testWeightValidation() throws {
        // Navigate to physical info step
        app.buttons["Next"].tap() // Welcome
        
        let ageField = app.textFields["Enter your age"]
        ageField.tap()
        ageField.typeText("25")
        
        app.buttons["Next"].tap() // Basic info
        
        let weightField = app.textFields["Enter your weight"]
        let nextButton = app.buttons["Next"]
        
        // Test invalid weight (too high)
        weightField.tap()
        weightField.typeText("2000")
        
        let heightField = app.textFields["Enter your height"]
        heightField.tap()
        heightField.typeText("170")
        
        nextButton.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Weight must be between'")).element.exists)
        
        // Clear and enter valid weight
        weightField.clearAndEnterText("70")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Weight must be between'")).element.exists)
    }
    
    func testHeightValidation() throws {
        // Navigate to physical info step
        app.buttons["Next"].tap() // Welcome
        
        let ageField = app.textFields["Enter your age"]
        ageField.tap()
        ageField.typeText("25")
        
        app.buttons["Next"].tap() // Basic info
        
        let weightField = app.textFields["Enter your weight"]
        weightField.tap()
        weightField.typeText("70")
        
        let heightField = app.textFields["Enter your height"]
        let nextButton = app.buttons["Next"]
        
        // Test invalid height (too high)
        heightField.tap()
        heightField.typeText("500")
        
        nextButton.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Height must be between'")).element.exists)
        
        // Clear and enter valid height
        heightField.clearAndEnterText("170")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Height must be between'")).element.exists)
    }
    
    func testBackNavigation() throws {
        // Navigate forward through steps
        app.buttons["Next"].tap() // Welcome -> Basic Info
        
        let ageField = app.textFields["Enter your age"]
        ageField.tap()
        ageField.typeText("25")
        
        app.buttons["Next"].tap() // Basic Info -> Physical Info
        
        // Test back button exists and works
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.exists)
        backButton.tap()
        
        // Should be back at basic info
        XCTAssertTrue(app.staticTexts["Basic Information"].exists)
        XCTAssertTrue(app.staticTexts["Step 2 of 5"].exists)
        
        // Age field should still have the entered value
        XCTAssertEqual(ageField.value as? String, "25")
    }
    
    func testProgressIndicator() throws {
        // Check initial progress
        let progressView = app.progressIndicators.element
        XCTAssertTrue(progressView.exists)
        
        // Navigate through steps and verify progress updates
        for step in 1...5 {
            XCTAssertTrue(app.staticTexts["Step \(step) of 5"].exists)
            
            if step < 5 {
                // Fill required fields for each step
                switch step {
                case 2:
                    let ageField = app.textFields["Enter your age"]
                    ageField.tap()
                    ageField.typeText("25")
                case 3:
                    let weightField = app.textFields["Enter your weight"]
                    weightField.tap()
                    weightField.typeText("70")
                    
                    let heightField = app.textFields["Enter your height"]
                    heightField.tap()
                    heightField.typeText("170")
                case 4:
                    let moderatelyActiveButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Moderately Active'")).element
                    moderatelyActiveButton.tap()
                default:
                    break
                }
                
                app.buttons["Next"].tap()
            }
        }
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non-string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}