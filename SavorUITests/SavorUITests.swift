import XCTest

final class SavorUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset"]
    }
    func reveal(_ element: XCUIElement) {
        for _ in 0..<9 { if element.exists && element.isHittable { return }; app.swipeUp() }
    }
    func testManualPantryPersists() throws {
        app.launch()
        app.buttons["firstIngredients"].tap()
        let name = app.textFields["ingredientName"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Carrots")
        let amount = app.textFields["ingredientQuantity"].firstMatch
        amount.tap(); amount.typeText("3")
        app.buttons["confirmIngredients"].tap()
        XCTAssertTrue(app.buttons["ingredient-Carrots"].waitForExistence(timeout: 5))
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        reveal(app.buttons["ingredient-Carrots"])
        XCTAssertTrue(app.buttons["ingredient-Carrots"].exists)
    }
    func testSampleMealProgressAndCookedHistory() throws {
        app.launchArguments.append("--sample"); app.launch()
        app.tabBars.buttons["Cook"].tap()
        let generate = app.buttons["generateMeals"]; reveal(generate); generate.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipeCard")).firstMatch; reveal(card); XCTAssertTrue(card.exists); card.tap()
        app.buttons["saveRecipe"].tap()
        for index in 0..<4 { let step = app.buttons["step-\(index)"]; reveal(step); XCTAssertTrue(step.exists); step.tap() }
        let finish = app.buttons["finishCooking"]; reveal(finish); XCTAssertTrue(finish.isEnabled); finish.tap()
        let confirm = app.buttons["confirmCooked"]; reveal(confirm); confirm.tap()
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.tabBars.buttons["Recipe box"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipeCard")).firstMatch.waitForExistence(timeout: 5))
        reveal(app.staticTexts["Cooked"]); XCTAssertTrue(app.staticTexts["Cooked"].exists)
    }
    func testSampleKitchenCanBeReplacedWithOwnPantry() throws {
        app.launchArguments.append("--sample"); app.launch()
        app.buttons["settings"].tap()
        app.buttons["Start my own pantry"].tap()
        let confirm = app.buttons["Clear sample & start fresh"]; XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts["Room for good things."].waitForExistence(timeout: 5))
    }
}
