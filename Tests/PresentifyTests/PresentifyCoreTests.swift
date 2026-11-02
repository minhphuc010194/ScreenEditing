import AppKit
import CoreEngine
import Foundation
@testable import PresentifyCore
import XCTest

final class PresentifyCoreTests: XCTestCase {
    private var testSuiteName: String!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testSuiteName = "presentify.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)
    }

    override func tearDown() {
        if let suite = testSuiteName {
            testDefaults?.removePersistentDomain(forName: suite)
        }
        testDefaults = nil
        testSuiteName = nil
        super.tearDown()
    }

    func testSmoothStrokeInterpolatesPointsAndHandlesEdgeCases() {
        var out = Array(repeating: CEPoint(x: 0, y: 0), count: 32)
        let emptyCount = out.withUnsafeMutableBufferPointer { outPtr in
            ce_smooth_stroke(nil, 0, outPtr.baseAddress, outPtr.count)
        }
        XCTAssertEqual(emptyCount, 0)

        let twoPoints = [CEPoint(x: 10, y: 20), CEPoint(x: 30, y: 40)]
        let twoCount = twoPoints.withUnsafeBufferPointer { inPtr in
            out.withUnsafeMutableBufferPointer { outPtr in
                ce_smooth_stroke(inPtr.baseAddress, inPtr.count, outPtr.baseAddress, outPtr.count)
            }
        }
        XCTAssertEqual(twoCount, 2)
        XCTAssertEqual(out[0].x, 10, accuracy: 1e-6)
        XCTAssertEqual(out[1].y, 40, accuracy: 1e-6)

        let rawPoints = [
            CEPoint(x: 0, y: 0),
            CEPoint(x: 20, y: 40),
            CEPoint(x: 50, y: 10),
            CEPoint(x: 80, y: 60)
        ]
        let smoothedCount = rawPoints.withUnsafeBufferPointer { inPtr in
            out.withUnsafeMutableBufferPointer { outPtr in
                ce_smooth_stroke(inPtr.baseAddress, inPtr.count, outPtr.baseAddress, outPtr.count)
            }
        }
        XCTAssertGreaterThan(smoothedCount, rawPoints.count)
        XCTAssertEqual(out[0].x, 0, accuracy: 1e-6)
        XCTAssertEqual(out[0].y, 0, accuracy: 1e-6)
        XCTAssertEqual(out[smoothedCount - 1].x, 80, accuracy: 1e-6)
        XCTAssertEqual(out[smoothedCount - 1].y, 60, accuracy: 1e-6)
    }

    func testConstrainLineSnapsTo45DegreeMultiples() {
        let start = CEPoint(x: 100, y: 100)
        let nearlyHorizontal = ce_constrain_line(start, CEPoint(x: 200, y: 110))
        XCTAssertEqual(nearlyHorizontal.y, 100.0, accuracy: 1e-6)
        XCTAssertGreaterThan(nearlyHorizontal.x, 200.0)

        let nearlyVertical = ce_constrain_line(start, CEPoint(x: 105, y: 220))
        XCTAssertEqual(nearlyVertical.x, 100.0, accuracy: 1e-6)
        XCTAssertGreaterThan(nearlyVertical.y, 210.0)

        let diagonal = ce_constrain_line(start, CEPoint(x: 195, y: 205))
        XCTAssertEqual(diagonal.x - start.x, diagonal.y - start.y, accuracy: 1e-6)
    }

    func testMakeRectNormalizesAndConstrainsSquare() {
        let rect = ce_make_rect(CEPoint(x: 100, y: 120), CEPoint(x: 40, y: 50), false)
        XCTAssertEqual(rect.x, 40.0, accuracy: 1e-6)
        XCTAssertEqual(rect.y, 50.0, accuracy: 1e-6)
        XCTAssertEqual(rect.width, 60.0, accuracy: 1e-6)
        XCTAssertEqual(rect.height, 70.0, accuracy: 1e-6)

        let square = ce_make_rect(CEPoint(x: 100, y: 100), CEPoint(x: 40, y: 60), true)
        XCTAssertEqual(square.width, 60.0, accuracy: 1e-6)
        XCTAssertEqual(square.height, 60.0, accuracy: 1e-6)
        XCTAssertEqual(square.x, 40.0, accuracy: 1e-6)
        XCTAssertEqual(square.y, 40.0, accuracy: 1e-6)
    }

    func testBuildArrowAndShapePolygons() {
        var arrowPoints = Array(repeating: CEPoint(x: 0, y: 0), count: 7)
        let arrowCount = arrowPoints.withUnsafeMutableBufferPointer { ptr in
            ce_build_arrow_polygon(
                CEPoint(x: 10, y: 20),
                CEPoint(x: 110, y: 20),
                6.0,
                ptr.baseAddress,
                ptr.count
            )
        }
        XCTAssertEqual(arrowCount, 7)
        XCTAssertEqual(arrowPoints[3].x, 110.0, accuracy: 1e-6)
        XCTAssertEqual(arrowPoints[3].y, 20.0, accuracy: 1e-6)

        let bounds = CERect(x: 10, y: 20, width: 100, height: 80)
        var shapeBuffer = Array(repeating: CEPoint(x: 0, y: 0), count: 64)

        let circleCount = shapeBuffer.withUnsafeMutableBufferPointer { ptr in
            ce_build_shape_polygon(0, bounds, ptr.baseAddress, ptr.count)
        }
        XCTAssertEqual(circleCount, 64)

        let squircleCount = shapeBuffer.withUnsafeMutableBufferPointer { ptr in
            ce_build_shape_polygon(1, bounds, ptr.baseAddress, ptr.count)
        }
        XCTAssertEqual(squircleCount, 64)

        let rectCount = shapeBuffer.withUnsafeMutableBufferPointer { ptr in
            ce_build_shape_polygon(2, bounds, ptr.baseAddress, ptr.count)
        }
        XCTAssertEqual(rectCount, 4)

        let rhombusCount = shapeBuffer.withUnsafeMutableBufferPointer { ptr in
            ce_build_shape_polygon(3, bounds, ptr.baseAddress, ptr.count)
        }
        XCTAssertEqual(rhombusCount, 4)
        XCTAssertEqual(shapeBuffer[0].x, 60.0, accuracy: 1e-6)
        XCTAssertEqual(shapeBuffer[0].y, 20.0, accuracy: 1e-6)
    }

    func testHitTestingIntersectionsBoundingBoxAndExpiration() {
        let stroke = [CEPoint(x: 0, y: 0), CEPoint(x: 100, y: 0), CEPoint(x: 100, y: 100)]
        let hitNearSegment = stroke.withUnsafeBufferPointer { ptr in
            ce_hit_test_stroke(ptr.baseAddress, ptr.count, 6.0, CEPoint(x: 50, y: 5), 4.0)
        }
        XCTAssertTrue(hitNearSegment)

        let missFarPoint = stroke.withUnsafeBufferPointer { ptr in
            ce_hit_test_stroke(ptr.baseAddress, ptr.count, 6.0, CEPoint(x: 50, y: 25), 4.0)
        }
        XCTAssertFalse(missFarPoint)

        let rect = CERect(x: 20, y: 20, width: 100, height: 100)
        XCTAssertFalse(ce_hit_test_rect(rect, false, 4.0, CEPoint(x: 70, y: 70), 2.0))
        XCTAssertTrue(ce_hit_test_rect(rect, true, 4.0, CEPoint(x: 70, y: 70), 2.0))
        XCTAssertTrue(ce_hit_test_rect(rect, false, 4.0, CEPoint(x: 21, y: 70), 2.0))

        let marqueeHit = stroke.withUnsafeBufferPointer { ptr in
            ce_rect_intersects_stroke(CERect(x: 40, y: -10, width: 20, height: 20), ptr.baseAddress, ptr.count)
        }
        XCTAssertTrue(marqueeHit)

        let marqueeMiss = stroke.withUnsafeBufferPointer { ptr in
            ce_rect_intersects_stroke(CERect(x: 20, y: 20, width: 30, height: 30), ptr.baseAddress, ptr.count)
        }
        XCTAssertFalse(marqueeMiss)

        let bbox = stroke.withUnsafeBufferPointer { ptr in
            ce_compute_bounding_box(ptr.baseAddress, ptr.count, 10.0)
        }
        XCTAssertEqual(bbox.x, -5.0, accuracy: 1e-6)
        XCTAssertEqual(bbox.y, -5.0, accuracy: 1e-6)
        XCTAssertEqual(bbox.width, 110.0, accuracy: 1e-6)
        XCTAssertEqual(bbox.height, 110.0, accuracy: 1e-6)

        XCTAssertFalse(ce_is_stroke_expired(10.0, 20.0, 3.0, false))
        XCTAssertFalse(ce_is_stroke_expired(10.0, 12.0, 3.0, true))
        XCTAssertTrue(ce_is_stroke_expired(10.0, 13.5, 3.0, true))
    }

    func testCanvasStateLifecycleSelectionCopyPasteUndoRedoAndSessionIO() {
        let canvas = AnnotationCanvasState()
        canvas.beginStroke(at: CGPoint(x: 10, y: 10), mode: .freeHand, color: .red, lineWeight: 6.0, isAutoErase: true, now: 100.0)
        canvas.updateStroke(to: CGPoint(x: 30, y: 20))
        canvas.updateStroke(to: CGPoint(x: 60, y: 15))
        canvas.updateStroke(to: CGPoint(x: 90, y: 30))
        canvas.finishStroke()

        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertGreaterThan(canvas.annotations[0].points.count, 4)

        canvas.addOrUpdateTextAnnotation(at: CGPoint(x: 200, y: 200), text: "ScreenEditing", color: .blue, now: 105.0)
        XCTAssertEqual(canvas.annotations.count, 2)

        let hitID = canvas.hitTestAnnotation(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(hitID, canvas.annotations[0].id)

        canvas.toggleSelection(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(canvas.selectedIDs, [canvas.annotations[0].id])

        XCTAssertTrue(canvas.copySelectedAnnotations())
        canvas.pasteAnnotations(offsetStep: 15.0)
        XCTAssertEqual(canvas.annotations.count, 3)
        XCTAssertEqual(canvas.annotations[2].startPoint.x, 25.0, accuracy: 1e-5)

        canvas.moveSelectedAnnotations(by: CGSize(width: 5.0, height: -5.0))
        XCTAssertEqual(canvas.annotations[2].startPoint.x, 30.0, accuracy: 1e-5)
        XCTAssertEqual(canvas.annotations[2].startPoint.y, 20.0, accuracy: 1e-5)

        canvas.undo()
        XCTAssertEqual(canvas.annotations[2].startPoint.x, 25.0, accuracy: 1e-5)
        canvas.redo()
        XCTAssertEqual(canvas.annotations[2].startPoint.x, 30.0, accuracy: 1e-5)

        guard let exported = canvas.exportSessionData() else {
            XCTFail("Expected session data export to succeed")
            return
        }
        canvas.clearAll()
        XCTAssertTrue(canvas.annotations.isEmpty)
        XCTAssertTrue(canvas.importSessionData(exported))
        XCTAssertEqual(canvas.annotations.count, 3)

        canvas.pruneExpiredAnnotations(now: 104.0, delay: 3.0)
        XCTAssertEqual(canvas.annotations.count, 2)
    }

    func testAppSettingsPersistenceHelpersAndRestoreDefaults() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertEqual(settings.favColors.count, 5)
        XCTAssertEqual(settings.lineWeight, 6.0, accuracy: 1e-6)
        XCTAssertEqual(settings.blurStyle, .gaussian)

        settings.setLineWeightFromDigit(1)
        XCTAssertEqual(settings.lineWeight, settings.minLineWeight, accuracy: 1e-6)
        settings.setLineWeightFromDigit(9)
        XCTAssertEqual(settings.lineWeight, settings.maxLineWeight, accuracy: 1e-6)

        settings.decreaseLineWeight(step: 4.0)
        XCTAssertEqual(settings.lineWeight, 20.0, accuracy: 1e-6)
        settings.increaseCursorSize(step: 15.0)
        XCTAssertEqual(settings.cursorHighlightSize, 75.0, accuracy: 1e-6)
        settings.increaseZoomLevel(step: 0.5)
        XCTAssertEqual(settings.zoomLevel, 2.5, accuracy: 1e-6)
        settings.blurStyle = .pixelate

        settings.selectRandomColors()
        XCTAssertTrue(settings.useRandomColors)
        XCTAssertTrue(settings.enableGradients)
        XCTAssertNotNil(settings.activeStrokeGradient)

        settings.selectFavoriteColor(index: 2)
        XCTAssertFalse(settings.useRandomColors)
        XCTAssertFalse(settings.enableGradients)
        XCTAssertNil(settings.activeStrokeGradient)
        XCTAssertEqual(settings.activeStrokeColor, settings.favColors[2])

        let customCyan = RGBColor(red: 0.1, green: 0.85, blue: 0.95)
        settings.setCustomStrokeColor(customCyan)
        XCTAssertFalse(settings.useRandomColors)
        XCTAssertFalse(settings.enableGradients)
        XCTAssertNil(settings.activeStrokeGradient)
        XCTAssertEqual(settings.activeStrokeColor, customCyan)

        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.lineWeight, 20.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.cursorHighlightSize, 75.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.zoomLevel, 2.5, accuracy: 1e-6)
        XCTAssertEqual(reloaded.blurStyle, .pixelate)
        XCTAssertNotNil(testDefaults.object(forKey: "presentify.blurStyle"))

        reloaded.restoreDefaults()
        XCTAssertEqual(reloaded.lineWeight, 6.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.cursorHighlightSize, 60.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.zoomLevel, 2.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.blurStyle, .gaussian)
        XCTAssertEqual(AppSettings(defaults: testDefaults).blurStyle, .gaussian)
    }

    func testShortcutManagerAll33DefaultBindingsAndCommandMatching() {
        XCTAssertEqual(ShortcutCommand.allCases.count, 33)
        XCTAssertEqual(ShortcutCategory.global.commands.count, 5)
        XCTAssertEqual(ShortcutCategory.annotate.commands.count, 23)
        XCTAssertEqual(ShortcutCategory.cursor.commands.count, 5)

        let manager = ShortcutManager(defaults: testDefaults)
        XCTAssertEqual(manager.binding(for: .toggleAnnotateScreen).displayString, "⌃⌥A")
        XCTAssertEqual(manager.binding(for: .toggleAnnotateControls).displayString, "⌃⌥W")
        XCTAssertEqual(manager.binding(for: .toggleHighlightCursor).displayString, "⌃⌥H")
        XCTAssertEqual(manager.binding(for: .toggleSpotlightCursor).displayString, "⌃⌥S")
        XCTAssertEqual(manager.binding(for: .toggleZoomCursor).displayString, "⌃⌥Z")
        XCTAssertEqual(manager.binding(for: .clearAnnotate).displayString, "Delete")
        XCTAssertEqual(manager.binding(for: .blur).displayString, "B")
        XCTAssertEqual(manager.binding(for: .setLineWeight).displayString, "⌃⌥1")
        XCTAssertEqual(manager.binding(for: .copyScreenshot).displayString, "⌘C")
        XCTAssertEqual(manager.binding(for: .pasteAnnotations).displayString, "⌘V")
        XCTAssertEqual(manager.binding(for: .decreaseZoomLevel).displayString, "⌥-")
        XCTAssertEqual(manager.binding(for: .increaseZoomLevel).displayString, "⌥=")
        XCTAssertEqual(manager.binding(for: .toggleZoomFullScreen).displayString, "⌥0")

        let ctrlOpt = KeyBinding.controlMask | KeyBinding.optionMask
        let digitMatch = manager.matchLocalAnnotateCommand(keyCode: 0x17, modifiers: ctrlOpt)
        XCTAssertEqual(digitMatch?.command, .setLineWeight)
        XCTAssertEqual(digitMatch?.lineWeightDigit, 5)

        let arrowMatch = manager.matchLocalAnnotateCommand(keyCode: 0x00, modifiers: 0)
        XCTAssertEqual(arrowMatch?.command, .arrow)
        XCTAssertNil(arrowMatch?.lineWeightDigit)

        let blurMatch = manager.matchLocalAnnotateCommand(keyCode: 0x0B, modifiers: 0)
        XCTAssertEqual(blurMatch?.command, .blur)
        XCTAssertNil(blurMatch?.lineWeightDigit)

        XCTAssertNil(manager.matchCursorCommand(keyCode: 0x1D, modifiers: KeyBinding.optionMask, isZoomActive: false))
        XCTAssertEqual(
            manager.matchCursorCommand(keyCode: 0x1D, modifiers: KeyBinding.optionMask, isZoomActive: true),
            .toggleZoomFullScreen
        )

        let custom = KeyBinding(keyCode: 0x05, modifiers: KeyBinding.commandMask | KeyBinding.shiftMask)
        manager.setBinding(custom, for: .freeHand)
        let persistedManager = ShortcutManager(defaults: testDefaults)
        XCTAssertEqual(persistedManager.binding(for: .freeHand), custom)
        XCTAssertEqual(persistedManager.binding(for: .freeHand).displayString, "⇧⌘G")

        persistedManager.resetToDefault(for: .freeHand)
        XCTAssertEqual(persistedManager.binding(for: .freeHand).displayString, "F")
    }

    func testAnnotateOverlayCanvasInteractiveModeToastAndScreenshotter() {
        let settings = AppSettings(defaults: testDefaults)
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts)

        overlay.showAnnotation()
        XCTAssertTrue(settings.isAnnotating)
        XCTAssertNotNil(overlay.panel)
        XCTAssertNotNil(overlay.canvasView)
        XCTAssertNotNil(overlay.controlsPanel)

        if let panel = overlay.panel, let controlsPanel = overlay.controlsPanel {
            XCTAssertGreaterThan(controlsPanel.level.rawValue, panel.level.rawValue)
            XCTAssertFalse(controlsPanel.isMovableByWindowBackground)
            XCTAssertFalse(controlsPanel.canBecomeKey)
        }

        settings.annotateInteractiveMode = true
        settings.interactiveModeKey = .fn
        overlay.updateInteractivePassThrough(modifierFlags: [])
        XCTAssertEqual(overlay.panel?.ignoresMouseEvents, true)
        overlay.updateInteractivePassThrough(modifierFlags: [.function])
        XCTAssertEqual(overlay.panel?.ignoresMouseEvents, false)

        guard let canvasView = overlay.canvasView else {
            XCTFail("Expected canvasView to be initialized")
            return
        }
        XCTAssertTrue(canvasView.acceptsFirstMouse(for: nil))

        settings.selectOrToggleDrawMode(.arrow)
        XCTAssertEqual(settings.currentDrawMode, .arrow)
        settings.selectOrToggleDrawMode(.rectangle)
        XCTAssertEqual(settings.currentDrawMode, .rectangle)
        settings.selectOrToggleDrawMode(.circle)
        XCTAssertEqual(settings.currentDrawMode, .circle)
        settings.selectOrToggleDrawMode(.highlighter)
        XCTAssertEqual(settings.currentDrawMode, .highlighter)
        settings.selectOrToggleDrawMode(.highlighter)
        XCTAssertEqual(settings.currentDrawMode, .freeHand)

        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x04, modifiers: 0))
        XCTAssertEqual(settings.currentDrawMode, .highlighter)
        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x04, modifiers: 0))
        XCTAssertEqual(settings.currentDrawMode, .freeHand)

        if let keyEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "r",
            charactersIgnoringModifiers: "r",
            isARepeat: false,
            keyCode: 0x0F
        ) {
            overlay.controlsPanel?.keyDown(with: keyEvent)
            XCTAssertEqual(settings.currentDrawMode, .rectangle)
        }

        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x0D, modifiers: 0))
        XCTAssertTrue(settings.isWhiteboardActive)

        canvasView.beginInlineTextEditing(at: CGPoint(x: 40, y: 40))
        XCTAssertEqual(canvasView.activeTextField?.placeholderString, "Type something...")
        canvasView.activeTextField?.stringValue = "Hello Screen"
        canvasView.commitActiveTextEditing()
        XCTAssertEqual(overlay.canvasState.annotations.count, 1)
        XCTAssertEqual(overlay.canvasState.annotations.last?.text, "Hello Screen")

        if let undoEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 0x06
        ) {
            XCTAssertTrue(canvasView.performKeyEquivalent(with: undoEvent))
            XCTAssertEqual(overlay.canvasState.annotations.count, 0)
        }

        if let redoEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "Z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 0x06
        ) {
            XCTAssertTrue(canvasView.performKeyEquivalent(with: redoEvent))
            XCTAssertEqual(overlay.canvasState.annotations.count, 1)
        }

        if let undoAgainEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 0x06
        ) {
            XCTAssertTrue(canvasView.performKeyEquivalent(with: undoAgainEvent))
            XCTAssertEqual(overlay.canvasState.annotations.count, 0)
        }

        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x10, modifiers: KeyBinding.commandMask))
        XCTAssertEqual(overlay.canvasState.annotations.count, 1)

        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x00, modifiers: KeyBinding.commandMask))
        XCTAssertEqual(overlay.canvasState.selectedIDs.count, 1)

        var didSaveScreenshotViaCmdS = false
        canvasView.onRequestSaveScreenshot = { didSaveScreenshotViaCmdS = true }
        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x01, modifiers: KeyBinding.commandMask))
        XCTAssertTrue(didSaveScreenshotViaCmdS)

        XCTAssertFalse(settings.isShowingShortcutsCheatsheet)
        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x2C, modifiers: KeyBinding.shiftMask))
        XCTAssertTrue(settings.isShowingShortcutsCheatsheet)

        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x75, modifiers: 0))
        XCTAssertEqual(overlay.canvasState.annotations.count, 0)

        let toast = overlay.toastController
        toast.showToast(.touchDraw, message: "Touch Draw On", autoDismissAfter: 0)
        XCTAssertEqual(toast.currentToast, .touchDraw)
        toast.dismissAndDontShowAgain()
        XCTAssertFalse(settings.toastTouchDraw)
        toast.showToast(.touchDraw, message: "Should Not Appear", autoDismissAfter: 0)
        XCTAssertNil(toast.currentToast)

        XCTAssertNil(Screenshotter.validateDirectoryPath(""))
        XCTAssertNil(Screenshotter.validateDirectoryPath("/nonexistent-presentify-dir-\(UUID().uuidString)"))
        let tempDir = NSTemporaryDirectory()
        XCTAssertNotNil(Screenshotter.validateDirectoryPath(tempDir))
        if let savedURL = Screenshotter.saveViewScreenshot(canvasView, directoryPath: tempDir, playSound: false) {
            XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
            XCTAssertTrue(savedURL.lastPathComponent.hasPrefix("ScreenEditing-Screenshot-"))
            try? FileManager.default.removeItem(at: savedURL)
        } else {
            XCTFail("Expected screenshot file to be written")
        }

        overlay.hideAnnotation()
        XCTAssertFalse(settings.isAnnotating)

        settings.showAnnotateControls = false
        overlay.toggleAnnotateControls()
        XCTAssertTrue(settings.isAnnotating)
        XCTAssertTrue(settings.showAnnotateControls)
        overlay.hideAnnotation()
    }

    func testCursorControllersAndAppControllerRouting() {
        let settings = AppSettings(defaults: testDefaults)
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let appController = PresentifyAppController(settings: settings, shortcutManager: shortcuts)

        appController.setupMainMenu()
        if let mainMenu = NSApp?.mainMenu,
           let appSubmenu = mainMenu.items.first?.submenu {
            XCTAssertTrue(appSubmenu.items.contains(where: { $0.keyEquivalent == "q" }))
            XCTAssertTrue(appSubmenu.items.contains(where: { $0.keyEquivalent == "," }))
        }

        appController.handleGlobalShortcut(.toggleHighlightCursor)
        XCTAssertTrue(settings.isHighlightingCursor)
        appController.highlightController.simulateClickDown()
        XCTAssertEqual(appController.highlightController.highlightView?.isMousePressed, true)
        appController.highlightController.simulateClickUp()
        XCTAssertEqual(appController.highlightController.highlightView?.isMousePressed, false)

        let initialHighlightSize = settings.cursorHighlightSize
        XCTAssertTrue(appController.handleAppKeyDown(keyCode: 0x18, modifiers: 0))
        XCTAssertGreaterThan(settings.cursorHighlightSize, initialHighlightSize)
        XCTAssertTrue(appController.handleAppKeyDown(keyCode: 0x35, modifiers: 0))
        XCTAssertFalse(settings.isHighlightingCursor)

        appController.handleGlobalShortcut(.toggleSpotlightCursor)
        XCTAssertTrue(settings.isSpotlightingCursor)
        appController.spotlightController.updateCursorPosition(CGPoint(x: 300, y: 250))
        appController.handleGlobalShortcut(.toggleSpotlightCursor)
        XCTAssertFalse(settings.isSpotlightingCursor)

        appController.handleGlobalShortcut(.toggleZoomCursor)
        XCTAssertTrue(settings.isZoomingCursor)
        XCTAssertTrue(
            appController.zoomController.handleCursorShortcut(
                keyCode: 0x1D,
                modifiers: KeyBinding.optionMask
            )
        )
        XCTAssertTrue(settings.zoomFullScreen)
        appController.handleGlobalShortcut(.toggleZoomCursor)
        XCTAssertFalse(settings.isZoomingCursor)

        appController.annotateController.showAnnotation()
        XCTAssertTrue(settings.isAnnotating)
        XCTAssertTrue(appController.handleAppKeyDown(keyCode: 0x0D, modifiers: KeyBinding.commandMask))
        XCTAssertFalse(settings.isAnnotating)

        let dockMenu = appController.dockMenuController.buildDockMenu()
        XCTAssertEqual(dockMenu.title, "ScreenEditing")
        XCTAssertGreaterThanOrEqual(dockMenu.items.count, 5)
        XCTAssertEqual(WelcomeTourView.pages.count, 6)
        XCTAssertEqual(WelcomeTourView.pages.first?.title, "Welcome to ScreenEditing")
        XCTAssertEqual(SettingsView.appVersionText, "Version 8.1.2 (Build 68)")
        XCTAssertEqual(SettingsView.copyrightText, "© Châu Minh Phúc. All rights reserved.")
        XCTAssertNotNil(SettingsView.appIconImage())
        XCTAssertEqual(AppSettings.defaultHighlightColor, .blue)

        let primaryBlue = NSColor(SettingsView.themeBlue).usingColorSpace(.sRGB)
        let lightBlue = NSColor(SettingsView.themeLightBlue).usingColorSpace(.sRGB)
        XCTAssertNotNil(primaryBlue)
        XCTAssertNotNil(lightBlue)
        if let primaryBlue, let lightBlue {
            XCTAssertGreaterThan(primaryBlue.blueComponent, primaryBlue.redComponent)
            XCTAssertGreaterThan(primaryBlue.blueComponent, primaryBlue.greenComponent)
            XCTAssertGreaterThan(lightBlue.blueComponent, lightBlue.redComponent)
            XCTAssertGreaterThan(lightBlue.blueComponent, lightBlue.greenComponent)
        }

        XCTAssertNil(appController.settingsWindow)
        XCTAssertTrue(appController.handleAppKeyDown(keyCode: 0x2B, modifiers: KeyBinding.commandMask))
        XCTAssertNotNil(appController.settingsWindow)
        appController.settingsWindow?.close()

        XCTAssertTrue(appController.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        XCTAssertNotNil(appController.settingsWindow)
        appController.settingsWindow?.close()
    }

    func testAppUpdaterVersionComparisonAndReleaseParsing() {
        XCTAssertTrue(AppUpdater.isVersion("8.2.0", newerThan: "8.1.2"))
        XCTAssertTrue(AppUpdater.isVersion("v8.1.3", newerThan: "8.1.2"))
        XCTAssertTrue(AppUpdater.isVersion("8.1.2.1", newerThan: "8.1.2"))
        XCTAssertFalse(AppUpdater.isVersion("8.1.2", newerThan: "8.1.2"))
        XCTAssertFalse(AppUpdater.isVersion("8.0.9", newerThan: "8.1.2"))

        let validAsset = ReleaseAssetInfo(
            name: "ScreenEditing.app.zip",
            browserDownloadURL: "https://github.com/minhphuc010194/ScreenEditing/releases/download/v8.2.0/ScreenEditing.app.zip",
            size: 1024
        )
        let untrustedAsset = ReleaseAssetInfo(
            name: "ScreenEditing.app.zip",
            browserDownloadURL: "https://evil.example.com/ScreenEditing.app.zip",
            size: 1024
        )
        XCTAssertNil(AppUpdater.validatedZipAssetURL(in: [untrustedAsset]))
        XCTAssertNotNil(AppUpdater.validatedZipAssetURL(in: [untrustedAsset, validAsset]))

        let settings = AppSettings(defaults: testDefaults)
        let updater = AppUpdater(settings: settings)
        var notifiedRelease: GitHubReleaseInfo?
        updater.onUpdateAvailable = { release in
            notifiedRelease = release
        }

        let notFoundStatus = updater.processReleaseResponse(
            ReleaseHTTPResponse(data: Data(), statusCode: 404),
            mode: .automatic
        )
        XCTAssertEqual(notFoundStatus, .upToDate(currentVersion: updater.currentVersion))

        let newerJSON = """
        {
          "tag_name": "v9.0.0",
          "name": "ScreenEditing 9.0.0",
          "body": "Major update with new tools.",
          "html_url": "https://github.com/minhphuc010194/ScreenEditing/releases/tag/v9.0.0",
          "assets": [
            {
              "name": "ScreenEditing.app.zip",
              "url": "https://api.github.com/repos/minhphuc010194/ScreenEditing/releases/assets/12345",
              "browser_download_url": "https://github.com/minhphuc010194/ScreenEditing/releases/download/v9.0.0/ScreenEditing.app.zip",
              "size": 2048
            }
          ]
        }
        """.data(using: .utf8)!

        let availableStatus = updater.processReleaseResponse(
            ReleaseHTTPResponse(data: newerJSON, statusCode: 200),
            mode: .automatic
        )
        if case .updateAvailable(let release) = availableStatus {
            XCTAssertEqual(release.tagName, "v9.0.0")
            XCTAssertEqual(notifiedRelease?.tagName, "v9.0.0")
            XCTAssertEqual(
                release.assets.first?.apiURL,
                "https://api.github.com/repos/minhphuc010194/ScreenEditing/releases/assets/12345"
            )
            XCTAssertEqual(
                AppUpdater.validatedAPIAssetURL(in: release.assets)?.absoluteString,
                "https://api.github.com/repos/minhphuc010194/ScreenEditing/releases/assets/12345"
            )
            updater.skipRelease(release)
        } else {
            XCTFail("Expected updateAvailable status")
        }

        XCTAssertEqual(settings.skippedUpdateVersion, "v9.0.0")
        let skippedAutoStatus = updater.processReleaseResponse(
            ReleaseHTTPResponse(data: newerJSON, statusCode: 200),
            mode: .automatic
        )
        XCTAssertEqual(skippedAutoStatus, .upToDate(currentVersion: updater.currentVersion))

        let manualOverrideStatus = updater.processReleaseResponse(
            ReleaseHTTPResponse(data: newerJSON, statusCode: 200),
            mode: .userInitiated
        )
        if case .updateAvailable(let release) = manualOverrideStatus {
            XCTAssertEqual(release.tagName, "v9.0.0")
        } else {
            XCTFail("Expected user-initiated check to show update even if previously skipped")
        }
    }

    func testBlurToolShortcutGeometryModifiersHitTestAndLegacySession() {
        XCTAssertEqual(DrawMode.blur.title, "Blur")
        XCTAssertEqual(DrawMode.blur.systemImage, "checkerboard.rectangle")
        XCTAssertTrue(DrawMode.allCases.contains(.blur))
        XCTAssertEqual(BlurStyle.gaussian.title, "Gaussian Blur")
        XCTAssertEqual(BlurStyle.pixelate.title, "Pixelate")
        XCTAssertEqual(BlurStyle.allCases, [.gaussian, .pixelate])

        let optionTip = AnnotateShortcutsView.modifierTips.first { $0.symbol == "⌥ Option" }
        XCTAssertEqual(
            optionTip?.description,
            "Hold while drawing a rectangle/circle to fill, or blur to switch Gaussian/Pixelate."
        )

        let settings = AppSettings(defaults: testDefaults)
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let canvasView = AnnotateCanvasView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 300),
            canvasState: canvas,
            settings: settings,
            shortcutManager: shortcuts
        )

        XCTAssertTrue(canvasView.handleKeyCommand(keyCode: 0x0B, modifiers: 0))
        XCTAssertEqual(settings.currentDrawMode, .blur)

        canvas.beginStroke(
            at: CGPoint(x: 120, y: 150),
            mode: .blur,
            color: .red,
            lineWeight: 8.0,
            isAutoErase: true,
            blurStyle: .gaussian,
            now: 50.0
        )
        canvas.updateStroke(to: CGPoint(x: 40, y: 50))
        canvas.finishStroke()

        XCTAssertEqual(canvas.annotations.count, 1)
        let firstBlur = canvas.annotations[0]
        XCTAssertEqual(firstBlur.boundingRect, CGRect(x: 40, y: 50, width: 80, height: 100))
        XCTAssertEqual(firstBlur.effectiveBlurStyle, .gaussian)
        XCTAssertEqual(canvas.hitTestAnnotation(at: CGPoint(x: 80, y: 100)), firstBlur.id)
        XCTAssertNil(canvas.hitTestAnnotation(at: CGPoint(x: 5, y: 5)))

        canvas.beginStroke(
            at: CGPoint(x: 100, y: 100),
            mode: .blur,
            color: .blue,
            lineWeight: 10.0,
            isShiftDown: true,
            isOptionDown: true,
            blurStyle: .gaussian,
            now: 60.0
        )
        canvas.updateStroke(to: CGPoint(x: 40, y: 60), isShiftDown: true, isOptionDown: true)
        canvas.finishStroke()

        let constrainedBlur = canvas.annotations[1]
        XCTAssertEqual(constrainedBlur.boundingRect.width, 60.0, accuracy: 1e-6)
        XCTAssertEqual(constrainedBlur.boundingRect.height, 60.0, accuracy: 1e-6)
        XCTAssertEqual(constrainedBlur.effectiveBlurStyle, .pixelate)

        let invertedPixelate = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 20, y: 20),
            isFilled: true,
            strokeColor: .red,
            blurStyle: .pixelate
        )
        XCTAssertEqual(invertedPixelate.effectiveBlurStyle, .gaussian)

        let nilBlurDefault = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 20, y: 20),
            isFilled: false,
            strokeColor: .red
        )
        XCTAssertEqual(nilBlurDefault.effectiveBlurStyle, .gaussian)

        canvas.selectAnnotations(in: CGRect(x: 70, y: 90, width: 15, height: 15))
        XCTAssertTrue(canvas.selectedIDs.contains(firstBlur.id))
        canvas.selectedIDs = [firstBlur.id]
        canvas.moveSelectedAnnotations(by: CGSize(width: 10, height: -5))
        XCTAssertEqual(canvas.annotations[0].boundingRect, CGRect(x: 50, y: 45, width: 80, height: 100))

        XCTAssertTrue(canvas.copySelectedAnnotations())
        canvas.pasteAnnotations(offsetStep: 12.0)
        XCTAssertEqual(canvas.annotations.count, 3)
        XCTAssertEqual(canvas.annotations[2].mode, .blur)

        canvas.undo()
        XCTAssertEqual(canvas.annotations.count, 2)
        canvas.redo()
        XCTAssertEqual(canvas.annotations.count, 3)

        canvas.pruneExpiredAnnotations(now: 55.0, delay: 3.0)
        XCTAssertEqual(canvas.annotations.count, 2)

        let legacyJSON = """
        [
          {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "rectangle",
            "points": [[10, 20], [60, 80]],
            "startPoint": [10, 20],
            "endPoint": [60, 80],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 1, "green": 0, "blue": 0, "alpha": 1},
            "lineWeight": 6,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 24
          }
        ]
        """.data(using: .utf8)!
        XCTAssertTrue(canvas.importSessionData(legacyJSON))
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertNil(canvas.annotations[0].blurStyle)
        XCTAssertEqual(canvas.annotations[0].effectiveBlurStyle, .gaussian)

        let legacyBlurJSON = """
        [
          {
            "id": "A621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "blur",
            "points": [[15, 25], [95, 105]],
            "startPoint": [15, 25],
            "endPoint": [95, 105],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 0, "green": 0, "blue": 1, "alpha": 1},
            "lineWeight": 8,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 120,
            "text": "",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 24
          }
        ]
        """.data(using: .utf8)!
        XCTAssertTrue(canvas.importSessionData(legacyBlurJSON))
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations[0].mode, .blur)
        XCTAssertNil(canvas.annotations[0].blurStyle)
        XCTAssertEqual(canvas.annotations[0].effectiveBlurStyle, .gaussian)

        let zeroClickCanvas = AnnotationCanvasState()
        zeroClickCanvas.beginStroke(
            at: CGPoint(x: 80, y: 80),
            mode: .blur,
            color: .blue,
            lineWeight: 6.0,
            blurStyle: .gaussian
        )
        zeroClickCanvas.finishStroke()
        XCTAssertTrue(zeroClickCanvas.annotations.isEmpty)
        XCTAssertTrue(zeroClickCanvas.undoStack.isEmpty)

        zeroClickCanvas.beginStroke(
            at: CGPoint(x: 80, y: 80),
            mode: .blur,
            color: .blue,
            lineWeight: 6.0,
            blurStyle: .pixelate
        )
        zeroClickCanvas.updateStroke(to: CGPoint(x: 81.2, y: 110.0))
        zeroClickCanvas.finishStroke()
        XCTAssertTrue(zeroClickCanvas.annotations.isEmpty)
        XCTAssertTrue(zeroClickCanvas.undoStack.isEmpty)
    }

    func testBlurFilterGaussianAndPixelateAndScreenCaptureBoundsGuard() {
        let captureManager = ScreenCaptureManager()
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: 0, y: 0, width: 1.5, height: 40), excludingWindowID: nil))
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: 0, y: 0, width: 40, height: 1.5), excludingWindowID: nil))
        XCTAssertNil(captureManager.captureScreenRect(.null, excludingWindowID: nil))

        guard let sourceImage = makeTestSourceImage(size: 64) else {
            XCTFail("Expected synthetic source CGImage")
            return
        }

        let gaussianItem = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 64, y: 64),
            strokeColor: .blue,
            lineWeight: 6.0,
            blurStyle: .gaussian
        )
        guard let gaussianImage = AnnotateCanvasView.applyBlurFilter(to: sourceImage, item: gaussianItem) else {
            XCTFail("Expected Gaussian filtered CGImage")
            return
        }
        XCTAssertEqual(gaussianImage.width, 64)
        XCTAssertEqual(gaussianImage.height, 64)

        if let seamPixel = rgbaPixel(in: gaussianImage, at: (x: 32, y: 32)),
           let leftEdgePixel = rgbaPixel(in: gaussianImage, at: (x: 2, y: 32)) {
            XCTAssertGreaterThan(seamPixel.r, 50)
            XCTAssertGreaterThan(seamPixel.b, 50)
            XCTAssertEqual(seamPixel.a, 255)
            XCTAssertGreaterThan(leftEdgePixel.r, 150)
            XCTAssertEqual(leftEdgePixel.a, 255)
        } else {
            XCTFail("Expected readable pixels from Gaussian image")
        }

        let pixelateItem = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 64, y: 64),
            strokeColor: .blue,
            lineWeight: 8.0,
            blurStyle: .pixelate
        )
        guard let pixelatedImage = AnnotateCanvasView.applyBlurFilter(to: sourceImage, item: pixelateItem) else {
            XCTFail("Expected Pixelate filtered CGImage")
            return
        }
        XCTAssertEqual(pixelatedImage.width, 64)
        XCTAssertEqual(pixelatedImage.height, 64)

        var equalAdjacentRedPairs = 0
        for x in 2..<28 {
            if let current = rgbaPixel(in: pixelatedImage, at: (x: x, y: 32)),
               let next = rgbaPixel(in: pixelatedImage, at: (x: x + 1, y: 32)) {
                if current.r == next.r {
                    equalAdjacentRedPairs += 1
                }
            }
        }
        XCTAssertGreaterThanOrEqual(equalAdjacentRedPairs, 16)

        let optionToggledItem = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 64, y: 64),
            isFilled: true,
            strokeColor: .blue,
            lineWeight: 8.0,
            blurStyle: .gaussian
        )
        if let optionImage = AnnotateCanvasView.applyBlurFilter(to: sourceImage, item: optionToggledItem),
           let p1 = rgbaPixel(in: pixelatedImage, at: (x: 12, y: 32)),
           let p2 = rgbaPixel(in: optionImage, at: (x: 12, y: 32)) {
            XCTAssertEqual(p1.r, p2.r)
            XCTAssertEqual(p1.b, p2.b)
        } else {
            XCTFail("Expected Option-toggled Gaussian item to match Pixelate output")
        }
    }

    func testBlurFilterRetinaBackingScaleAndMonotonicLineWeightScaling() {
        guard let image1x = makeTestSourceImage(size: 64),
              let image2x = makeTestSourceImage(size: 128) else {
            XCTFail("Expected 1x and 2x synthetic source images")
            return
        }

        let retinaGaussItem = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 64, y: 64),
            strokeColor: .blue,
            lineWeight: 2.0,
            blurStyle: .gaussian
        )
        XCTAssertEqual(image2x.width, 2 * Int(retinaGaussItem.boundingRect.width))

        let unscaled128GaussItem = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 128, y: 128),
            strokeColor: .blue,
            lineWeight: 2.0,
            blurStyle: .gaussian
        )

        guard let gauss1x = AnnotateCanvasView.applyBlurFilter(to: image1x, item: retinaGaussItem),
              let gauss2x = AnnotateCanvasView.applyBlurFilter(to: image2x, item: retinaGaussItem),
              let gaussUnscaled = AnnotateCanvasView.applyBlurFilter(to: image2x, item: unscaled128GaussItem),
              let sample1x = rgbaPixel(in: gauss1x, at: (x: 24, y: 32)),
              let sample2x = rgbaPixel(in: gauss2x, at: (x: 48, y: 64)),
              let sampleUnscaled = rgbaPixel(in: gaussUnscaled, at: (x: 48, y: 64)) else {
            XCTFail("Expected 1x and 2x Gaussian filtered samples")
            return
        }
        XCTAssertGreaterThan(sample2x.b, 30)
        XCTAssertLessThanOrEqual(abs(Int(sample2x.b) - Int(sample1x.b)), 6)
        XCTAssertLessThanOrEqual(abs(Int(sample2x.r) - Int(sample1x.r)), 6)
        XCTAssertGreaterThan(Int(sample2x.b), Int(sampleUnscaled.b) + 15)

        let retinaPixItem = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 64, y: 64),
            strokeColor: .blue,
            lineWeight: 2.0,
            blurStyle: .pixelate
        )
        guard let pix1x = AnnotateCanvasView.applyBlurFilter(to: image1x, item: retinaPixItem),
              let pix2x = AnnotateCanvasView.applyBlurFilter(to: image2x, item: retinaPixItem),
              let anchor1x = rgbaPixel(in: pix1x, at: (x: 16, y: 32)),
              let anchor2x = rgbaPixel(in: pix2x, at: (x: 32, y: 64)) else {
            XCTFail("Expected 1x and 2x Pixelate filtered samples")
            return
        }

        var plateau1x = 0
        for x in 0..<pix1x.width {
            if let px = rgbaPixel(in: pix1x, at: (x: x, y: 32)) {
                let matchesAnchor = px.r == anchor1x.r && px.b == anchor1x.b
                if matchesAnchor {
                    plateau1x += 1
                }
            }
        }
        var plateau2x = 0
        for x in 0..<pix2x.width {
            if let px = rgbaPixel(in: pix2x, at: (x: x, y: 64)) {
                let matchesAnchor = px.r == anchor2x.r && px.b == anchor2x.b
                if matchesAnchor {
                    plateau2x += 1
                }
            }
        }
        XCTAssertGreaterThanOrEqual(plateau1x, 9)
        XCTAssertGreaterThanOrEqual(plateau2x, 18)
        XCTAssertEqual(Double(plateau2x) / 2.0, Double(plateau1x), accuracy: 2.0)

        let weights: [Double] = [2.0, 3.0, 6.0, 20.0]
        var gaussianBleeds: [UInt8] = []
        for weight in weights {
            let item = AnnotationItem(
                mode: .blur,
                startPoint: .zero,
                endPoint: CGPoint(x: 128, y: 128),
                strokeColor: .blue,
                lineWeight: weight,
                blurStyle: .gaussian
            )
            guard let out = AnnotateCanvasView.applyBlurFilter(to: image2x, item: item),
                  let px = rgbaPixel(in: out, at: (x: 44, y: 64)) else {
                XCTFail("Expected Gaussian output for weight \(weight)")
                return
            }
            gaussianBleeds.append(px.b)
        }
        XCTAssertLessThan(gaussianBleeds[0], gaussianBleeds[1])
        XCTAssertLessThan(gaussianBleeds[1], gaussianBleeds[2])
        XCTAssertLessThan(gaussianBleeds[2], gaussianBleeds[3])

        let pixWeights: [Double] = [2.0, 6.0, 20.0]
        var pixTransitions: [Int] = []
        for weight in pixWeights {
            let item = AnnotationItem(
                mode: .blur,
                startPoint: .zero,
                endPoint: CGPoint(x: 128, y: 128),
                strokeColor: .blue,
                lineWeight: weight,
                blurStyle: .pixelate
            )
            guard let out = AnnotateCanvasView.applyBlurFilter(to: image2x, item: item) else {
                XCTFail("Expected Pixelate output for weight \(weight)")
                return
            }
            var transitions = 0
            for x in 0..<(out.width - 1) {
                if let c1 = rgbaPixel(in: out, at: (x: x, y: 64)),
                   let c2 = rgbaPixel(in: out, at: (x: x + 1, y: 64)) {
                    let changed = c1.r != c2.r || c1.b != c2.b
                    if changed {
                        transitions += 1
                    }
                }
            }
            pixTransitions.append(transitions)
        }
        XCTAssertGreaterThan(pixTransitions[0], pixTransitions[1])
        XCTAssertGreaterThan(pixTransitions[1], pixTransitions[2])
    }

    func testBlurCanvasRenderingCachingAndFailClosedRedactionInScreenshotter() {
        let settings = AppSettings(defaults: testDefaults)
        settings.annotateToolIndicator = false
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let view = AnnotateCanvasView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 200),
            canvasState: canvas,
            settings: settings,
            shortcutManager: shortcuts
        )

        canvas.annotations = [
            AnnotationItem(
                mode: .rectangle,
                startPoint: CGPoint(x: 60, y: 60),
                endPoint: CGPoint(x: 140, y: 140),
                isFilled: true,
                strokeColor: RGBColor(red: 0.0, green: 1.0, blue: 0.0),
                lineWeight: 4.0
            ),
            AnnotationItem(
                mode: .blur,
                startPoint: CGPoint(x: 60, y: 60),
                endPoint: CGPoint(x: 140, y: 140),
                strokeColor: .blue,
                lineWeight: 8.0,
                blurStyle: .gaussian
            )
        ]

        guard let fallbackPNG = Screenshotter.renderViewToPNGData(view),
              let fallbackCG = NSBitmapImageRep(data: fallbackPNG)?.cgImage else {
            XCTFail("Expected PNG data for fail-closed blur fallback")
            return
        }
        if let center = rgbaPixel(in: fallbackCG, at: (x: fallbackCG.width / 2, y: fallbackCG.height / 2)),
           let outside = rgbaPixel(in: fallbackCG, at: (x: fallbackCG.width / 10, y: fallbackCG.height / 10)) {
            XCTAssertEqual(center.a, 255)
            XCTAssertLessThan(center.g, 120)
            XCTAssertEqual(outside.a, 0)
        } else {
            XCTFail("Expected readable pixels from fallback PNG")
        }

        var captureCalls = 0
        view.regionCaptureProvider = { _ in
            captureCalls += 1
            return self.makeTestSourceImage(size: 64)
        }

        canvas.annotations = [
            AnnotationItem(
                mode: .blur,
                startPoint: CGPoint(x: 99.5, y: 80),
                endPoint: CGPoint(x: 100.5, y: 120),
                strokeColor: .blue,
                lineWeight: 6.0
            )
        ]
        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(captureCalls, 0)

        canvas.clearAll()
        canvas.beginStroke(at: CGPoint(x: 60, y: 60), mode: .blur, color: .blue, lineWeight: 6.0, blurStyle: .gaussian)
        canvas.updateStroke(to: CGPoint(x: 140, y: 140))
        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(captureCalls, 1)

        canvas.finishStroke()
        guard let capturedPNG = Screenshotter.renderViewToPNGData(view),
              let capturedCG = NSBitmapImageRep(data: capturedPNG)?.cgImage else {
            XCTFail("Expected PNG data for captured blur region")
            return
        }
        XCTAssertEqual(captureCalls, 2)
        if let center = rgbaPixel(in: capturedCG, at: (x: capturedCG.width / 2, y: capturedCG.height / 2)) {
            XCTAssertEqual(center.a, 255)
            XCTAssertGreaterThan(center.r, 40)
            XCTAssertGreaterThan(center.b, 40)
        } else {
            XCTFail("Expected center pixel from captured blur PNG")
        }

        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(captureCalls, 2)

        canvas.selectedIDs = Set(canvas.annotations.map(\.id))
        canvas.moveSelectedAnnotations(by: CGSize(width: 10, height: 0))
        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(captureCalls, 3)

        settings.isWhiteboardActive = true
        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(captureCalls, 3)

        settings.isWhiteboardActive = false
        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(captureCalls, 4)
    }

    func testBlurSessionImportValidationAndExtremeInMemoryBoundsSafety() {
        let canvas = AnnotationCanvasState()
        let seedItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50),
            strokeColor: .blue,
            lineWeight: 6.0
        )
        canvas.annotations = [seedItem]

        let overflowCoordJSON = """
        [
          {
            "id": "1621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "blur",
            "points": [[-1e308, 0], [1e308, 100]],
            "startPoint": [-1e308, 0],
            "endPoint": [1e308, 100],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 0, "green": 0, "blue": 1, "alpha": 1},
            "lineWeight": 6,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 24
          }
        ]
        """.data(using: .utf8)!
        XCTAssertFalse(canvas.importSessionData(overflowCoordJSON))
        XCTAssertEqual(canvas.annotations, [seedItem])

        let outOfRangePointsJSON = """
        [
          {
            "id": "2621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "freeHand",
            "points": [[10, 10], [40000, 20]],
            "startPoint": [10, 10],
            "endPoint": [20, 20],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 1, "green": 0, "blue": 0, "alpha": 1},
            "lineWeight": 6,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 24
          }
        ]
        """.data(using: .utf8)!
        XCTAssertFalse(canvas.importSessionData(outOfRangePointsJSON))
        XCTAssertEqual(canvas.annotations, [seedItem])

        let extremeWeightsJSON = """
        [
          {
            "id": "3621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "blur",
            "points": [[20, 20], [120, 120]],
            "startPoint": [20, 20],
            "endPoint": [120, 120],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 0, "green": 0, "blue": 1, "alpha": 1},
            "lineWeight": 1e20,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 1e20
          },
          {
            "id": "4621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "text",
            "points": [[30, 30]],
            "startPoint": [30, 30],
            "endPoint": [30, 30],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 0, "green": 0, "blue": 1, "alpha": 1},
            "lineWeight": -5,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "Hi",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 1
          }
        ]
        """.data(using: .utf8)!
        XCTAssertTrue(canvas.importSessionData(extremeWeightsJSON))
        XCTAssertEqual(canvas.annotations.count, 2)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].fontSize, 200.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].fontSize, 8.0, accuracy: 1e-6)

        let captureManager = ScreenCaptureManager()
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: Double.nan, y: 0, width: 40, height: 40), excludingWindowID: nil))
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: -1e308, y: 0, width: Double.infinity, height: 100), excludingWindowID: nil))
        XCTAssertNil(captureManager.captureScreenRect(.infinite, excludingWindowID: nil))
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: 200_000, y: 200_000, width: 100, height: 100), excludingWindowID: nil))

        let settings = AppSettings(defaults: testDefaults)
        settings.annotateToolIndicator = false
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let extremeCanvas = AnnotationCanvasState()
        let view = AnnotateCanvasView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 200),
            canvasState: extremeCanvas,
            settings: settings,
            shortcutManager: shortcuts
        )

        let hugeBlurItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: -20_000, y: -20_000),
            endPoint: CGPoint(x: 20_000, y: 20_000),
            strokeColor: .blue,
            lineWeight: 1e20,
            blurStyle: .gaussian
        )
        let nonFiniteBlurItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: -1e308, y: 0),
            endPoint: CGPoint(x: 1e308, y: 100),
            strokeColor: .blue,
            lineWeight: .nan,
            blurStyle: .pixelate
        )
        extremeCanvas.annotations = [hugeBlurItem, nonFiniteBlurItem]
        extremeCanvas.selectedIDs = [hugeBlurItem.id, nonFiniteBlurItem.id]

        guard let fallbackPNG = Screenshotter.renderViewToPNGData(view),
              let fallbackCG = NSBitmapImageRep(data: fallbackPNG)?.cgImage,
              let fallbackCenter = rgbaPixel(in: fallbackCG, at: (x: fallbackCG.width / 2, y: fallbackCG.height / 2)) else {
            XCTFail("Expected safe fallback render for 40000x40000 and non-finite blur items")
            return
        }
        XCTAssertEqual(fallbackCenter.a, 255)

        var capturedRects: [CGRect] = []
        view.regionCaptureProvider = { rect in
            capturedRects.append(rect)
            return self.makeTestSourceImage(size: 128)
        }
        view.clearBlurCache()

        guard let clippedCapturePNG = Screenshotter.renderViewToPNGData(view),
              let clippedCaptureCG = NSBitmapImageRep(data: clippedCapturePNG)?.cgImage,
              let clippedCenter = rgbaPixel(in: clippedCaptureCG, at: (x: clippedCaptureCG.width / 2, y: clippedCaptureCG.height / 2)) else {
            XCTFail("Expected safe clipped capture render for 40000x40000 blur item")
            return
        }
        XCTAssertEqual(capturedRects, [CGRect(x: 0, y: 0, width: 200, height: 200)])
        XCTAssertEqual(clippedCenter.a, 255)
    }

    func testScreenCaptureManagerFrameCroppingAt1xAnd2xAndLifecycle() {
        let captureManager = ScreenCaptureManager()
        var firstFrameCount = 0
        captureManager.onFirstFrameCaptured = {
            firstFrameCount += 1
        }

        XCTAssertNil(captureManager.latestFrame)
        XCTAssertTrue(captureManager.capturedDisplayFrame.isNull)
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: 10, y: 10, width: 50, height: 30), excludingWindowID: nil))

        guard let image1x = makeQuadrantTestImage(width: 200, height: 100),
              let image2x = makeQuadrantTestImage(width: 400, height: 200) else {
            XCTFail("Expected 1x and 2x quadrant test images")
            return
        }

        let display1x = CGRect(x: 0, y: 0, width: 200, height: 100)
        captureManager.updateCapturedFrame(image1x, displayFrame: display1x)
        XCTAssertEqual(firstFrameCount, 1)
        XCTAssertEqual(captureManager.capturedDisplayFrame, display1x)
        XCTAssertEqual(captureManager.latestFrame?.width, 200)

        captureManager.updateCapturedFrame(image1x, displayFrame: display1x)
        XCTAssertEqual(firstFrameCount, 1)

        guard let topLeft1x = captureManager.captureScreenRect(CGRect(x: 10, y: 60, width: 50, height: 30), excludingWindowID: nil),
              let bottomLeft1x = captureManager.captureScreenRect(CGRect(x: 10, y: 10, width: 50, height: 30), excludingWindowID: nil),
              let topRight1x = captureManager.captureScreenRect(CGRect(x: 120, y: 60, width: 50, height: 30), excludingWindowID: nil),
              let bottomRight1x = captureManager.captureScreenRect(CGRect(x: 120, y: 10, width: 50, height: 30), excludingWindowID: nil) else {
            XCTFail("Expected cropped 1x quadrant images")
            return
        }
        XCTAssertEqual(topLeft1x.width, 50)
        XCTAssertEqual(topLeft1x.height, 30)

        if let tlPx = rgbaPixel(in: topLeft1x, at: (x: 25, y: 15)),
           let blPx = rgbaPixel(in: bottomLeft1x, at: (x: 25, y: 15)),
           let trPx = rgbaPixel(in: topRight1x, at: (x: 25, y: 15)),
           let brPx = rgbaPixel(in: bottomRight1x, at: (x: 25, y: 15)) {
            XCTAssertGreaterThan(tlPx.r, 200)
            XCTAssertLessThan(tlPx.g, 50)
            XCTAssertLessThan(tlPx.b, 50)
            XCTAssertEqual(tlPx.a, 255)

            XCTAssertLessThan(blPx.r, 50)
            XCTAssertLessThan(blPx.g, 70)
            XCTAssertGreaterThan(blPx.b, 200)
            XCTAssertEqual(blPx.a, 255)

            XCTAssertLessThan(trPx.r, 50)
            XCTAssertGreaterThan(trPx.g, 200)
            XCTAssertLessThan(trPx.b, 60)
            XCTAssertEqual(trPx.a, 255)

            XCTAssertGreaterThan(brPx.r, 200)
            XCTAssertGreaterThan(brPx.g, 190)
            XCTAssertLessThan(brPx.b, 50)
            XCTAssertEqual(brPx.a, 255)
        } else {
            XCTFail("Expected readable pixels from 1x quadrant crops")
        }

        captureManager.stopStream()
        XCTAssertNil(captureManager.latestFrame)
        XCTAssertTrue(captureManager.capturedDisplayFrame.isNull)
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: 10, y: 60, width: 50, height: 30), excludingWindowID: nil))

        let display2x = CGRect(x: 300, y: 150, width: 200, height: 100)
        captureManager.updateCapturedFrame(image2x, displayFrame: display2x)
        XCTAssertEqual(firstFrameCount, 2)
        XCTAssertEqual(captureManager.capturedDisplayFrame, display2x)

        guard let topLeft2x = captureManager.captureScreenRect(CGRect(x: 310, y: 210, width: 40, height: 25), excludingWindowID: nil),
              let bottomLeft2x = captureManager.captureScreenRect(CGRect(x: 310, y: 160, width: 40, height: 25), excludingWindowID: nil),
              let topRight2x = captureManager.captureScreenRect(CGRect(x: 420, y: 210, width: 40, height: 25), excludingWindowID: nil),
              let bottomRight2x = captureManager.captureScreenRect(CGRect(x: 420, y: 160, width: 40, height: 25), excludingWindowID: nil) else {
            XCTFail("Expected cropped 2x Retina quadrant images")
            return
        }
        XCTAssertEqual(topLeft2x.width, 80)
        XCTAssertEqual(topLeft2x.height, 50)
        XCTAssertEqual(bottomRight2x.width, 80)
        XCTAssertEqual(bottomRight2x.height, 50)

        if let tl2x = rgbaPixel(in: topLeft2x, at: (x: 40, y: 25)),
           let bl2x = rgbaPixel(in: bottomLeft2x, at: (x: 40, y: 25)),
           let tr2x = rgbaPixel(in: topRight2x, at: (x: 40, y: 25)),
           let br2x = rgbaPixel(in: bottomRight2x, at: (x: 40, y: 25)) {
            XCTAssertGreaterThan(tl2x.r, 200)
            XCTAssertLessThan(tl2x.b, 50)
            XCTAssertGreaterThan(bl2x.b, 200)
            XCTAssertLessThan(bl2x.r, 50)
            XCTAssertGreaterThan(tr2x.g, 200)
            XCTAssertLessThan(tr2x.r, 50)
            XCTAssertGreaterThan(br2x.r, 200)
            XCTAssertGreaterThan(br2x.g, 190)
        } else {
            XCTFail("Expected readable pixels from 2x Retina quadrant crops")
        }

        if let regionAround = captureManager.captureRegionAround(
            screenPoint: CGPoint(x: 330, y: 220),
            captureSize: CGSize(width: 20, height: 20),
            excludingWindowID: nil
        ), let regionPx = rgbaPixel(in: regionAround, at: (x: 20, y: 20)) {
            XCTAssertEqual(regionAround.width, 40)
            XCTAssertEqual(regionAround.height, 40)
            XCTAssertGreaterThan(regionPx.r, 200)
            XCTAssertLessThan(regionPx.b, 50)
        } else {
            XCTFail("Expected captureRegionAround to crop from SCStream frame")
        }

        guard let clippedTopLeft2x = captureManager.captureScreenRect(
            CGRect(x: 260, y: 220, width: 70, height: 50),
            excludingWindowID: nil
        ), let clippedBottomRight2x = captureManager.captureScreenRect(
            CGRect(x: 475, y: 130, width: 60, height: 40),
            excludingWindowID: nil
        ) else {
            XCTFail("Expected partial off-display 2x Retina crops to clip cleanly")
            return
        }
        XCTAssertEqual(clippedTopLeft2x.width, 60)
        XCTAssertEqual(clippedTopLeft2x.height, 60)
        XCTAssertEqual(clippedBottomRight2x.width, 50)
        XCTAssertEqual(clippedBottomRight2x.height, 40)
        if let clippedTLPx = rgbaPixel(in: clippedTopLeft2x, at: (x: 30, y: 30)),
           let clippedBRPx = rgbaPixel(in: clippedBottomRight2x, at: (x: 25, y: 20)) {
            XCTAssertGreaterThan(clippedTLPx.r, 200)
            XCTAssertLessThan(clippedTLPx.b, 50)
            XCTAssertGreaterThan(clippedBRPx.r, 200)
            XCTAssertGreaterThan(clippedBRPx.g, 190)
            XCTAssertLessThan(clippedBRPx.b, 50)
        } else {
            XCTFail("Expected readable pixels from partial off-display 2x crops")
        }
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: 250, y: 160, width: 51, height: 30), excludingWindowID: nil))

        captureManager.stopStream()
        XCTAssertNil(captureManager.latestFrame)
        XCTAssertNil(captureManager.captureScreenRect(CGRect(x: 310, y: 210, width: 40, height: 25), excludingWindowID: nil))

        let bgCaptureManager = ScreenCaptureManager()
        let firstFrameExpectation = expectation(description: "Background updateCapturedFrame delivers onFirstFrameCaptured on main queue")
        var deliveredOnMainThread = false
        bgCaptureManager.onFirstFrameCaptured = {
            deliveredOnMainThread = Thread.isMainThread
            firstFrameExpectation.fulfill()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            bgCaptureManager.updateCapturedFrame(image2x, displayFrame: display2x)
        }
        wait(for: [firstFrameExpectation], timeout: 2.0)
        XCTAssertTrue(deliveredOnMainThread)
        XCTAssertEqual(bgCaptureManager.capturedDisplayFrame, display2x)
        XCTAssertEqual(bgCaptureManager.latestFrame?.width, 400)
        bgCaptureManager.stopStream()
    }

    func testBackdropBlurRegionViewLifecycleAndOpaqueScreenshotExport() {
        let settings = AppSettings(defaults: testDefaults)
        settings.annotateToolIndicator = false
        settings.whiteboardEnabled = false
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let view = AnnotateCanvasView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 240),
            canvasState: canvas,
            settings: settings,
            shortcutManager: shortcuts
        )
        XCTAssertNil(view.regionCaptureProvider)
        XCTAssertTrue(view.backdropBlurViews.isEmpty)

        canvas.beginStroke(at: CGPoint(x: 60, y: 60), mode: .blur, color: .blue, lineWeight: 8.0, blurStyle: .gaussian)
        canvas.updateStroke(to: CGPoint(x: 240, y: 180))
        view.syncBackdropBlurViews()
        XCTAssertEqual(view.backdropBlurViews.count, 1)
        if let draftID = canvas.activeDraft?.id, let draftBackdrop = view.backdropBlurViews[draftID] {
            XCTAssertEqual(draftBackdrop.borderStyle, .draft)
            XCTAssertEqual(draftBackdrop.layer?.borderWidth ?? 0, 1.5, accuracy: 1e-6)
        } else {
            XCTFail("Expected draft BackdropBlurRegionView while dragging blur stroke")
        }

        canvas.finishStroke()
        view.syncBackdropBlurViews()
        XCTAssertEqual(canvas.annotations.count, 1)
        let blurID = canvas.annotations[0].id
        guard let backdropView = view.backdropBlurViews[blurID] else {
            XCTFail("Expected committed BackdropBlurRegionView")
            return
        }
        XCTAssertTrue(backdropView.superview === view)
        XCTAssertEqual(backdropView.blendingMode, .behindWindow)
        XCTAssertEqual(backdropView.material, .selection)
        XCTAssertFalse(backdropView.isEmphasized)
        XCTAssertEqual(backdropView.state, .active)
        XCTAssertNil(backdropView.hitTest(NSPoint(x: 10, y: 10)))
        XCTAssertEqual(backdropView.frame, CGRect(x: 60, y: 60, width: 180, height: 120))
        XCTAssertEqual(backdropView.borderStyle, .committed)
        XCTAssertEqual(backdropView.layer?.borderWidth ?? 0, 1.0, accuracy: 1e-6)

        guard let exportedPNG = Screenshotter.renderViewToPNGData(view),
              let exportedCG = NSBitmapImageRep(data: exportedPNG)?.cgImage else {
            XCTFail("Expected Screenshotter PNG while BackdropBlurRegionView is mounted")
            return
        }
        if let centerPx = rgbaPixel(in: exportedCG, at: (x: exportedCG.width / 2, y: exportedCG.height / 2)),
           let innerCornerPx = rgbaPixel(in: exportedCG, at: (x: exportedCG.width / 3, y: exportedCG.height / 3)),
           let outsidePx = rgbaPixel(in: exportedCG, at: (x: 10, y: 10)) {
            XCTAssertEqual(centerPx.a, 255)
            XCTAssertLessThan(centerPx.g, 120)
            XCTAssertEqual(innerCornerPx.a, 255)
            XCTAssertEqual(outsidePx.a, 0)
        } else {
            XCTFail("Expected readable pixels from exported PNG with mounted backdrop view")
        }
        XCTAssertFalse(backdropView.isHidden)
        XCTAssertTrue(backdropView.superview === view)

        canvas.selectedIDs = [blurID]
        canvas.moveSelectedAnnotations(by: CGSize(width: 15, height: -10))
        view.syncBackdropBlurViews()
        XCTAssertEqual(backdropView.frame, CGRect(x: 75, y: 50, width: 180, height: 120))

        canvas.annotations[0].endPoint = CGPoint(x: 195, y: 150)
        view.syncBackdropBlurViews()
        XCTAssertEqual(backdropView.frame, CGRect(x: 75, y: 50, width: 120, height: 100))

        view.regionCaptureProvider = { _ in
            self.makeQuadrantTestImage(width: 120, height: 100)
        }
        XCTAssertTrue(view.backdropBlurViews.isEmpty)
        XCTAssertNil(backdropView.superview)

        guard let capturedPNG = Screenshotter.renderViewToPNGData(view),
              let capturedCG = NSBitmapImageRep(data: capturedPNG)?.cgImage,
              let capturedMid = rgbaPixel(in: capturedCG, at: (x: capturedCG.width / 2, y: capturedCG.height / 2)) else {
            XCTFail("Expected blurred CGImage render when regionCaptureProvider returns an image")
            return
        }
        XCTAssertEqual(capturedMid.a, 255)
        XCTAssertGreaterThan(Int(capturedMid.r) + Int(capturedMid.g) + Int(capturedMid.b), 120)

        canvas.annotations[0].blurStyle = .pixelate
        view.clearBlurCache()
        guard let pixPNG = Screenshotter.renderViewToPNGData(view),
              let pixCG = NSBitmapImageRep(data: pixPNG)?.cgImage,
              let pixMid = rgbaPixel(in: pixCG, at: (x: pixCG.width / 2, y: pixCG.height / 2)) else {
            XCTFail("Expected pixelated CGImage render when blurStyle is pixelate")
            return
        }
        XCTAssertEqual(pixMid.a, 255)

        var draftCaptureCalls = 0
        view.regionCaptureProvider = { _ in
            draftCaptureCalls += 1
            return self.makeQuadrantTestImage(width: 120, height: 100)
        }
        canvas.clearAll()
        canvas.beginStroke(at: CGPoint(x: 40, y: 40), mode: .blur, color: .blue, lineWeight: 8.0, blurStyle: .gaussian)
        canvas.updateStroke(to: CGPoint(x: 160, y: 140))
        view.syncBackdropBlurViews()
        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(draftCaptureCalls, 1)

        canvas.updateStroke(to: CGPoint(x: 180, y: 150))
        view.syncBackdropBlurViews()
        _ = Screenshotter.renderViewToPNGData(view)
        XCTAssertEqual(draftCaptureCalls, 2)
        canvas.finishStroke()

        view.regionCaptureProvider = nil
        XCTAssertEqual(view.backdropBlurViews.count, 1)

        settings.whiteboardEnabled = true
        view.syncBackdropBlurViews()
        XCTAssertTrue(view.backdropBlurViews.isEmpty)

        settings.whiteboardEnabled = false
        view.syncBackdropBlurViews()
        XCTAssertEqual(view.backdropBlurViews.count, 1)

        view.removeAllBackdropBlurViews()
        canvas.clearAll()
        view.beginInlineTextEditing(at: CGPoint(x: 80, y: 90))
        guard let activeField = view.activeTextField else {
            XCTFail("Expected activeTextField after beginInlineTextEditing")
            return
        }
        canvas.annotations = [
            AnnotationItem(
                mode: .blur,
                startPoint: CGPoint(x: 50, y: 50),
                endPoint: CGPoint(x: 200, y: 170),
                strokeColor: .blue,
                lineWeight: 6.0,
                blurStyle: .gaussian
            )
        ]
        view.syncBackdropBlurViews()
        if let orderedBackdrop = view.backdropBlurViews.values.first,
           let backdropIndex = view.subviews.firstIndex(of: orderedBackdrop) {
            if let textFieldIndex = view.subviews.firstIndex(of: activeField) {
                XCTAssertLessThan(backdropIndex, textFieldIndex)
            } else {
                XCTFail("Expected activeTextField in canvas subviews")
            }
        } else {
            XCTFail("Expected BackdropBlurRegionView mounted below activeTextField")
        }
        view.cancelActiveTextEditing()

        view.removeAllBackdropBlurViews()
        XCTAssertTrue(view.backdropBlurViews.isEmpty)

        let overlayCanvas = AnnotationCanvasState()
        overlayCanvas.annotations = [
            AnnotationItem(
                mode: .blur,
                startPoint: CGPoint(x: 50, y: 50),
                endPoint: CGPoint(x: 160, y: 140),
                strokeColor: .blue,
                lineWeight: 6.0,
                blurStyle: .gaussian
            )
        ]
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: overlayCanvas)
        overlay.showAnnotation()
        XCTAssertEqual(overlay.canvasView?.backdropBlurViews.count, 1)
        if let overlayView = overlay.canvasView,
           let overlayPNG = Screenshotter.renderViewToPNGData(overlayView),
           let overlayCG = NSBitmapImageRep(data: overlayPNG)?.cgImage {
            let scaleX = Double(overlayCG.width) / Double(max(1.0, overlayView.bounds.width))
            let scaleY = Double(overlayCG.height) / Double(max(1.0, overlayView.bounds.height))
            let sampleX = Int((105.0 * scaleX).rounded())
            let sampleY = Int((Double(overlayView.bounds.height - 95.0) * scaleY).rounded())
            if let overlayPx = rgbaPixel(in: overlayCG, at: (x: sampleX, y: sampleY)) {
                XCTAssertEqual(overlayPx.a, 255)
                XCTAssertLessThan(overlayPx.g, 120)
            } else {
                XCTFail("Expected readable pixel inside windowed overlay blur export")
            }
        } else {
            XCTFail("Expected PNG export from windowed AnnotateOverlayController canvasView")
        }
        overlay.hideAnnotation()
        XCTAssertEqual(overlay.canvasView?.backdropBlurViews.count, 0)
    }

    private func makeQuadrantTestImage(width: Int, height: Int) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let halfW = max(1, width / 2)
        let halfH = max(1, height / 2)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let isLeft = x < halfW
                let isTop = y < halfH
                if isLeft && isTop {
                    bytes[offset] = 240
                    bytes[offset + 1] = 20
                    bytes[offset + 2] = 20
                } else if !isLeft && isTop {
                    bytes[offset] = 20
                    bytes[offset + 1] = 230
                    bytes[offset + 2] = 30
                } else if isLeft && !isTop {
                    bytes[offset] = 20
                    bytes[offset + 1] = 40
                    bytes[offset + 2] = 245
                } else {
                    bytes[offset] = 240
                    bytes[offset + 1] = 220
                    bytes[offset + 2] = 20
                }
                bytes[offset + 3] = 255
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        return bytes.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: bitmapInfo
            ) else {
                return nil
            }
            return context.makeImage()
        }
    }

    private func makeTestSourceImage(size: Int) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        let half = max(1, size / 2)
        for y in 0..<size {
            for x in 0..<size {
                let offset = (y * size + x) * 4
                if x < half {
                    bytes[offset] = UInt8(min(255, 190 + (x * 64) / half))
                    bytes[offset + 1] = 0
                    bytes[offset + 2] = 0
                } else {
                    bytes[offset] = 0
                    bytes[offset + 1] = 0
                    bytes[offset + 2] = UInt8(min(255, 190 + ((x - half) * 64) / half))
                }
                bytes[offset + 3] = 255
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        return bytes.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: space,
                bitmapInfo: bitmapInfo
            ) else {
                return nil
            }
            return context.makeImage()
        }
    }

    private func rgbaPixel(in image: CGImage, at point: (x: Int, y: Int)) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        let withinX = point.x >= 0 && point.x < image.width
        let withinY = point.y >= 0 && point.y < image.height
        guard withinX && withinY else { return nil }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let drew = bytes.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: space,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drew else { return nil }
        let offset = (point.y * image.width + point.x) * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }
}
