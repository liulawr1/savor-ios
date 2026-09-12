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
    private func openLiveFixtureRecipe() {
        app.launchEnvironment["SAVOR_TEST_SERVER_URL"] = "http://127.0.0.1:8790"
        app.launchEnvironment["SAVOR_TEST_CLIENT_TOKEN"] = "savor-ui-fixture-token-32-characters"
        app.launch()
        app.buttons["firstIngredients"].tap()
        let name = app.textFields["ingredientName"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Canned chickpeas")
        let amount = app.textFields["ingredientQuantity"].firstMatch; amount.tap(); amount.typeText("1 can")
        app.buttons["confirmIngredients"].tap()
        app.tabBars.buttons["Cook"].tap()
        let generate = app.buttons["generateMeals"]; reveal(generate); generate.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipeCard")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8)); reveal(card); card.tap()
    }
    private func openAdjustment() {
        let adjust = app.buttons["makeThisWork"]; reveal(adjust); adjust.tap()
        XCTAssertTrue(app.buttons["microwaveAdjustment"].waitForExistence(timeout: 5))
    }
    func testAdjustmentKeepsOriginalAndPersistsFreshRevision() throws {
        openLiveFixtureRecipe()
        let step = app.buttons["step-0"]; reveal(step); step.tap()
        for _ in 0..<7 { if app.buttons["makeThisWork"].isHittable { break }; app.swipeDown() }
        openAdjustment()
        let editorShot = XCTAttachment(screenshot: app.screenshot()); editorShot.name = "Adjustment editor"; editorShot.lifetime = .keepAlways; add(editorShot)
        app.buttons["microwaveAdjustment"].tap()
        let submit = app.buttons["submitAdjustment"]; reveal(submit); submit.tap()
        XCTAssertTrue(app.staticTexts["adjustmentSummary"].waitForExistence(timeout: 8))
        let previewShot = XCTAttachment(screenshot: app.screenshot()); previewShot.name = "Revision preview"; previewShot.lifetime = .keepAlways; add(previewShot)
        let accept = app.buttons["acceptAdjustment"]; reveal(accept); accept.tap()
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.tabBars.buttons["Recipe box"].tap()
        let revision = app.buttons.containing(.staticText, identifier: "Microwave chickpea bowl").firstMatch
        XCTAssertTrue(revision.waitForExistence(timeout: 5)); reveal(revision); revision.tap()
        let freshStep = app.buttons["step-0"]; reveal(freshStep)
        XCTAssertEqual(freshStep.value as? String, "Not completed")
        app.terminate(); app.launch()
        app.tabBars.buttons["Recipe box"].tap()
        let original = app.buttons.containing(.staticText, identifier: "Warm chickpea bowl").firstMatch
        reveal(original); XCTAssertTrue(original.exists); original.tap()
        let keptStep = app.buttons["step-0"]; reveal(keptStep)
        XCTAssertEqual(keptStep.value as? String, "Completed")
    }
    func testAdjustmentFailureRetryAndDiscardKeepOriginal() throws {
        openLiveFixtureRecipe()
        app.buttons["saveRecipe"].tap()
        openAdjustment()
        let field = app.textFields["adjustmentRequest"]
        // A multiline SwiftUI field is exposed as a text view on some iOS versions.
        let requestField = field.exists ? field : app.textViews["adjustmentRequest"]
        requestField.tap(); requestField.typeText("fail")
        app.buttons["Done"].tap()
        let submit = app.buttons["submitAdjustment"]; reveal(submit); submit.tap()
        XCTAssertTrue(app.alerts["Couldn’t adjust this recipe"].waitForExistence(timeout: 8)); app.alerts.buttons["OK"].tap()
        for _ in 0..<6 { if app.buttons["microwaveAdjustment"].isHittable { break }; app.swipeDown() }
        app.buttons["microwaveAdjustment"].tap(); reveal(submit); submit.tap()
        XCTAssertTrue(app.staticTexts["adjustmentSummary"].waitForExistence(timeout: 8))
        let keep = app.buttons["keepOriginal"]; reveal(keep); keep.tap()
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.tabBars.buttons["Recipe box"].tap()
        XCTAssertTrue(app.staticTexts["Warm chickpea bowl"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Microwave chickpea bowl"].exists)
    }

    func testCancelAdjustmentDoesNotSaveLateResponse() throws {
        openLiveFixtureRecipe(); app.buttons["saveRecipe"].tap(); openAdjustment()
        let field = app.textFields["adjustmentRequest"]
        let requestField = field.exists ? field : app.textViews["adjustmentRequest"]
        requestField.tap(); requestField.typeText("slow microwave change"); app.buttons["Done"].tap()
        let submit = app.buttons["submitAdjustment"]; reveal(submit); submit.tap()
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["makeThisWork"].waitForExistence(timeout: 5))
        // Let the delayed fixture finish, then confirm no revision has appeared.
        let noPreview = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: app.staticTexts["revisionTitle"])
        XCTAssertEqual(XCTWaiter.wait(for: [noPreview], timeout: 3), .timedOut)
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.tabBars.buttons["Recipe box"].tap()
        XCTAssertTrue(app.staticTexts["Warm chickpea bowl"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Microwave chickpea bowl"].exists)
    }

}
