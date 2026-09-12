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
    private func toggleEquipment(_ name: String) {
        // SwiftUI exposes the whole labeled row as a switch. Tap its trailing control.
        app.switches["equipment-\(name)"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
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
        let equipment = app.buttons["editEquipment"]; reveal(equipment); equipment.tap()
        toggleEquipment("microwave"); toggleEquipment("stovetop")
        XCTAssertEqual(app.switches["equipment-microwave"].value as? String, "1")
        XCTAssertEqual(app.switches["equipment-stovetop"].value as? String, "1")
        app.buttons["saveEquipment"].tap()
        let generate = app.buttons["generateMeals"]; reveal(generate); generate.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipeCard")).firstMatch
        let found = card.waitForExistence(timeout: 8)
        if !found { let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Missing meal"; shot.lifetime = .keepAlways; add(shot) }
        XCTAssertTrue(found, app.debugDescription); reveal(card); card.tap()
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

    func testEquipmentProfilePersistsAndFlagsSavedRecipe() throws {
        openLiveFixtureRecipe(); app.buttons["saveRecipe"].tap()
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.buttons["settings"].tap()
        let equipment = app.buttons["settingsEquipment"]; reveal(equipment); equipment.tap()
        XCTAssertEqual(app.switches["equipment-microwave"].value as? String, "1")
        XCTAssertEqual(app.switches["equipment-stovetop"].value as? String, "1")
        toggleEquipment("stovetop")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Microwave kitchen profile"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["saveEquipment"].tap()
        app.terminate(); app.launch()
        app.buttons["settings"].tap(); reveal(equipment); equipment.tap()
        XCTAssertEqual(app.switches["equipment-microwave"].value as? String, "1")
        XCTAssertEqual(app.switches["equipment-stovetop"].value as? String, "0")
        app.buttons["Cancel"].tap(); app.buttons["Done"].tap()
        app.tabBars.buttons["Recipe box"].tap()
        let original = app.buttons.containing(.staticText, identifier: "Warm chickpea bowl").firstMatch; reveal(original); original.tap()
        let mismatch = app.staticTexts["equipmentMismatch"]; reveal(mismatch); XCTAssertTrue(mismatch.exists)
        for _ in 0..<6 { if app.buttons["makeThisWork"].isHittable { break }; app.swipeDown() }
        openAdjustment(); app.buttons["microwaveAdjustment"].tap()
        let submit = app.buttons["submitAdjustment"]; reveal(submit); submit.tap()
        XCTAssertTrue(app.staticTexts["adjustmentSummary"].waitForExistence(timeout: 8))
        let required = app.staticTexts.matching(identifier: "requiredEquipment").matching(NSPredicate(format: "label == %@", "Microwave")).firstMatch; reveal(required); XCTAssertEqual(required.label, "Microwave")
        let accept = app.buttons["acceptAdjustment"]; reveal(accept); accept.tap()
        app.terminate(); app.launch()
        app.buttons["settings"].tap(); reveal(equipment); equipment.tap()
        toggleEquipment("microwave"); app.buttons["saveEquipment"].tap()
        app.terminate(); app.launch()
        app.buttons["settings"].tap(); reveal(equipment); equipment.tap()
        for item in ["microwave", "stovetop", "oven", "kettle"] { XCTAssertEqual(app.switches["equipment-\(item)"].value as? String, "0") }
        app.buttons["Cancel"].tap(); app.buttons["Done"].tap()
        app.tabBars.buttons["Pantry"].tap()
        let ingredient = app.buttons["ingredient-Canned chickpeas"]; reveal(ingredient); XCTAssertTrue(ingredient.exists)
    }
    func testEquipmentSetupIsExplicitAndSampleResetPreservesIt() throws {
        app.launch(); app.tabBars.buttons["Cook"].tap()
        app.buttons["editEquipment"].tap()
        for item in ["microwave", "stovetop", "oven", "kettle"] { XCTAssertEqual(app.switches["equipment-\(item)"].value as? String, "0") }
        toggleEquipment("kettle"); app.buttons["saveEquipment"].tap()
        app.tabBars.buttons["Pantry"].tap(); app.buttons["loadSample"].tap()
        app.buttons["settings"].tap(); app.buttons["Reset sample kitchen"].tap()
        let resetButtons = app.buttons.matching(identifier: "Reset sample kitchen")
        try XCTUnwrap(resetButtons.allElementsBoundByIndex.first { $0.isHittable }).tap()
        app.buttons["settings"].tap(); app.buttons["Start my own pantry"].tap()
        app.buttons["Clear sample & start fresh"].tap()
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.buttons["settings"].tap(); let equipment = app.buttons["settingsEquipment"]; reveal(equipment); equipment.tap()
        XCTAssertEqual(app.switches["equipment-kettle"].value as? String, "1")
        XCTAssertEqual(app.switches["equipment-microwave"].value as? String, "0")
    }

}
