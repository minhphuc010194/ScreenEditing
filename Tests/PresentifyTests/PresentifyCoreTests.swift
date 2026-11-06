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
            XCTAssertEqual(draftBackdrop.borderWidth, 1.5, accuracy: 1e-6)
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
        XCTAssertEqual(backdropView.glassTier, .regular)
        XCTAssertEqual(backdropView.opacityLevel, 0.55, accuracy: 1e-6)
        XCTAssertNil(backdropView.tintColor)
        XCTAssertNotEqual(backdropView.layer?.masksToBounds, true)
        XCTAssertNil(backdropView.hitTest(NSPoint(x: 10, y: 10)))
        XCTAssertEqual(backdropView.frame, CGRect(x: 60, y: 60, width: 180, height: 120))
        XCTAssertEqual(backdropView.borderStyle, .committed)
        XCTAssertEqual(backdropView.borderWidth, 1.0, accuracy: 1e-6)

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

    func testBlurOpacityAndOptionalCustomTintSettingsLifecycle() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertEqual(settings.blurOpacity, 0.55, accuracy: 1e-6)
        XCTAssertFalse(settings.blurUseCustomColor)
        XCTAssertEqual(settings.blurCustomColor, AppSettings.defaultBlurCustomColor)
        XCTAssertNil(settings.activeBlurTintColor)

        settings.blurOpacity = 0.01
        XCTAssertEqual(settings.blurOpacity, 0.10, accuracy: 1e-6)
        settings.blurOpacity = 2.50
        XCTAssertEqual(settings.blurOpacity, 1.00, accuracy: 1e-6)
        settings.blurOpacity = .nan
        XCTAssertEqual(settings.blurOpacity, 0.55, accuracy: 1e-6)
        settings.blurOpacity = .infinity
        XCTAssertEqual(settings.blurOpacity, 0.55, accuracy: 1e-6)

        settings.blurOpacity = 0.55
        settings.increaseBlurOpacity()
        XCTAssertEqual(settings.blurOpacity, 0.65, accuracy: 1e-6)
        settings.decreaseBlurOpacity()
        XCTAssertEqual(settings.blurOpacity, 0.55, accuracy: 1e-6)
        settings.blurOpacity = 0.95
        settings.increaseBlurOpacity()
        XCTAssertEqual(settings.blurOpacity, 1.00, accuracy: 1e-6)
        settings.blurOpacity = 0.15
        settings.decreaseBlurOpacity()
        XCTAssertEqual(settings.blurOpacity, 0.10, accuracy: 1e-6)

        let customMint = RGBColor(red: 0.12, green: 0.84, blue: 0.52)
        settings.setCustomBlurTintColor(customMint)
        XCTAssertTrue(settings.blurUseCustomColor)
        XCTAssertEqual(settings.blurCustomColor, customMint)
        XCTAssertEqual(settings.activeBlurTintColor, customMint)

        settings.blurUseCustomColor = false
        XCTAssertEqual(settings.blurCustomColor, customMint)
        XCTAssertNil(settings.activeBlurTintColor)

        settings.blurUseCustomColor = true
        settings.blurOpacity = 0.80
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.blurOpacity, 0.80, accuracy: 1e-6)
        XCTAssertTrue(reloaded.blurUseCustomColor)
        XCTAssertEqual(reloaded.blurCustomColor, customMint)
        XCTAssertEqual(reloaded.activeBlurTintColor, customMint)

        testDefaults.set(Double.infinity, forKey: "presentify.blurOpacity")
        let sanitizedFromDefaults = AppSettings(defaults: testDefaults)
        XCTAssertEqual(sanitizedFromDefaults.blurOpacity, 0.55, accuracy: 1e-6)

        reloaded.restoreDefaults()
        XCTAssertEqual(reloaded.blurOpacity, 0.55, accuracy: 1e-6)
        XCTAssertFalse(reloaded.blurUseCustomColor)
        XCTAssertEqual(reloaded.blurCustomColor, AppSettings.defaultBlurCustomColor)
        XCTAssertNil(reloaded.activeBlurTintColor)

        CustomColorPanelBridge.shared.presentForBlurTint(for: reloaded)
        XCTAssertEqual(CustomColorPanelBridge.shared.activeTarget, .blurTint)
        CustomColorPanelBridge.shared.present(for: reloaded)
        XCTAssertEqual(CustomColorPanelBridge.shared.activeTarget, .stroke)
        CustomColorPanelBridge.shared.close()
    }

    func testBlurAnnotationShortcutsSelectionMutatorsAndSessionSanitization() throws {
        let legacyBlur = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 90, y: 70),
            strokeColor: .blue,
            lineWeight: 6.0
        )
        XCTAssertNil(legacyBlur.blurOpacity)
        XCTAssertEqual(legacyBlur.effectiveBlurOpacity, 0.55, accuracy: 1e-6)
        XCTAssertNil(legacyBlur.blurTintColor)

        var clampedItem = legacyBlur
        clampedItem.blurOpacity = 0.02
        XCTAssertEqual(clampedItem.effectiveBlurOpacity, 0.10, accuracy: 1e-6)
        clampedItem.blurOpacity = 1.90
        XCTAssertEqual(clampedItem.effectiveBlurOpacity, 1.00, accuracy: 1e-6)
        clampedItem.blurOpacity = .nan
        XCTAssertEqual(clampedItem.effectiveBlurOpacity, 0.55, accuracy: 1e-6)

        let settings = AppSettings(defaults: testDefaults)
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let view = AnnotateCanvasView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 240),
            canvasState: canvas,
            settings: settings,
            shortcutManager: shortcuts
        )

        var reportedLineWeights: [Double] = []
        var reportedBlurOpacities: [Double] = []
        view.onLineWeightChanged = { reportedLineWeights.append($0) }
        view.onBlurOpacityChanged = { reportedBlurOpacities.append($0) }

        settings.currentDrawMode = .freeHand
        settings.lineWeight = 6.0
        settings.blurOpacity = 0.55
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(settings.lineWeight, 8.0, accuracy: 1e-6)
        XCTAssertEqual(settings.blurOpacity, 0.55, accuracy: 1e-6)
        XCTAssertEqual(reportedLineWeights.count, 1)
        XCTAssertTrue(reportedBlurOpacities.isEmpty)

        settings.currentDrawMode = .blur
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(settings.lineWeight, 8.0, accuracy: 1e-6)
        XCTAssertEqual(settings.blurOpacity, 0.65, accuracy: 1e-6)
        XCTAssertEqual(reportedBlurOpacities.count, 1)
        XCTAssertEqual(reportedBlurOpacities.last ?? 0, 0.65, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(settings.blurOpacity, 0.55, accuracy: 1e-6)
        XCTAssertEqual(reportedBlurOpacities.count, 2)
        XCTAssertEqual(reportedBlurOpacities.last ?? 0, 0.55, accuracy: 1e-6)

        let blurEntry = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 120, y: 100),
            strokeColor: .blue,
            lineWeight: 6.0,
            blurStyle: .gaussian,
            blurOpacity: 0.40,
            blurTintColor: nil
        )
        let rectEntry = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 140, y: 20),
            endPoint: CGPoint(x: 220, y: 100),
            strokeColor: .red,
            lineWeight: 6.0
        )
        canvas.annotations = [blurEntry, rectEntry]
        canvas.selectedIDs = [blurEntry.id]
        settings.currentDrawMode = .rectangle
        settings.blurOpacity = 0.40

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(settings.blurOpacity, 0.50, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].effectiveBlurOpacity, 0.50, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 8.0, accuracy: 1e-6)

        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].effectiveBlurOpacity, 0.40, accuracy: 1e-6)
        canvas.redo()
        XCTAssertEqual(canvas.annotations[0].effectiveBlurOpacity, 0.50, accuracy: 1e-6)

        canvas.selectedIDs = [blurEntry.id]
        let undoCountBeforeNoOp = canvas.undoStack.count
        canvas.updateSelectedBlurOpacity(0.50)
        XCTAssertEqual(canvas.undoStack.count, undoCountBeforeNoOp)

        canvas.updateSelectedBlurTintColor(.green)
        XCTAssertEqual(canvas.annotations[0].blurTintColor, .green)
        XCTAssertNil(canvas.annotations[1].blurTintColor)
        canvas.undo()
        XCTAssertNil(canvas.annotations[0].blurTintColor)
        canvas.redo()
        XCTAssertEqual(canvas.annotations[0].blurTintColor, .green)

        canvas.selectedIDs = [blurEntry.id]
        canvas.updateSelectedBlurTintColor(nil)
        XCTAssertNil(canvas.annotations[0].blurTintColor)

        canvas.updateSelectedBlurStyle(.pixelate)
        XCTAssertEqual(canvas.annotations[0].blurStyle, .pixelate)
        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].blurStyle, .gaussian)

        canvas.selectedIDs = [blurEntry.id, rectEntry.id]
        let previousOpacity = settings.blurOpacity
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(settings.blurOpacity, previousOpacity, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 10.0, accuracy: 1e-6)

        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: AnnotationCanvasState())
        settings.currentDrawMode = .blur
        settings.blurOpacity = 0.55
        overlay.showAnnotation()
        _ = overlay.canvasView?.handleKeyCommand(keyCode: 0x1E, modifiers: 0)
        XCTAssertEqual(overlay.toastController.currentMessage, "Blur Opacity: 65%")
        overlay.hideAnnotation()

        let baseEncoded = try JSONEncoder().encode([blurEntry])
        var rawArray = try XCTUnwrap(JSONSerialization.jsonObject(with: baseEncoded) as? [[String: Any]])
        rawArray[0].removeValue(forKey: "blurOpacity")
        rawArray[0].removeValue(forKey: "blurTintColor")
        let legacyJSON = try JSONSerialization.data(withJSONObject: rawArray)
        let importedCanvas = AnnotationCanvasState()
        XCTAssertTrue(importedCanvas.importSessionData(legacyJSON))
        XCTAssertEqual(importedCanvas.annotations.count, 1)
        XCTAssertNil(importedCanvas.annotations[0].blurOpacity)
        XCTAssertEqual(importedCanvas.annotations[0].effectiveBlurOpacity, 0.55, accuracy: 1e-6)
        XCTAssertNil(importedCanvas.annotations[0].blurTintColor)

        let outOfRangeItems = [
            AnnotationItem(
                mode: .blur,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 50, y: 50),
                strokeColor: .blue,
                lineWeight: 6.0,
                blurOpacity: -3.0,
                blurTintColor: RGBColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.2)
            ),
            AnnotationItem(
                mode: .blur,
                startPoint: CGPoint(x: 60, y: 60),
                endPoint: CGPoint(x: 120, y: 120),
                strokeColor: .blue,
                lineWeight: 6.0,
                blurOpacity: 5.0
            )
        ]
        let encodedOut = try JSONEncoder().encode(outOfRangeItems)
        importedCanvas.importSessionData(encodedOut)
        XCTAssertEqual(importedCanvas.annotations.count, 2)
        XCTAssertEqual(importedCanvas.annotations[0].blurOpacity ?? 0, 0.10, accuracy: 1e-6)
        XCTAssertEqual(importedCanvas.annotations[0].blurTintColor?.alpha ?? 0, 1.0, accuracy: 1e-6)
        XCTAssertEqual(importedCanvas.annotations[1].blurOpacity ?? 0, 1.00, accuracy: 1e-6)
    }

    func testMonotonicBlurFilterAcrossOpacityLevels() {
        guard let splitSource = makeTestSourceImage(size: 160),
              let rampSource = makeHorizontalGradientImage(size: 160) else {
            XCTFail("Expected synthetic test source images")
            return
        }

        let gaussianLow = AnnotationItem(
            mode: .blur,
            startPoint: .zero,
            endPoint: CGPoint(x: 160, y: 160),
            strokeColor: .blue,
            lineWeight: 6.0,
            blurStyle: .gaussian,
            blurOpacity: 0.15
        )
        var gaussianMid = gaussianLow
        gaussianMid.blurOpacity = 0.55
        var gaussianHigh = gaussianLow
        gaussianHigh.blurOpacity = 1.00

        guard let gImgLow = AnnotateCanvasView.applyBlurFilter(to: splitSource, item: gaussianLow),
              let gImgMid = AnnotateCanvasView.applyBlurFilter(to: splitSource, item: gaussianMid),
              let gImgHigh = AnnotateCanvasView.applyBlurFilter(to: splitSource, item: gaussianHigh),
              let pxLow = rgbaPixel(in: gImgLow, at: (x: 62, y: 80)),
              let pxMid = rgbaPixel(in: gImgMid, at: (x: 62, y: 80)),
              let pxHigh = rgbaPixel(in: gImgHigh, at: (x: 62, y: 80)) else {
            XCTFail("Expected Gaussian blurred outputs across opacity levels")
            return
        }
        XCTAssertLessThan(pxLow.b, pxMid.b)
        XCTAssertLessThan(pxMid.b, pxHigh.b)

        var pixelLow = gaussianLow
        pixelLow.blurStyle = .pixelate
        var pixelMid = gaussianMid
        pixelMid.blurStyle = .pixelate
        var pixelHigh = gaussianHigh
        pixelHigh.blurStyle = .pixelate

        guard let pImgLow = AnnotateCanvasView.applyBlurFilter(to: rampSource, item: pixelLow),
              let pImgMid = AnnotateCanvasView.applyBlurFilter(to: rampSource, item: pixelMid),
              let pImgHigh = AnnotateCanvasView.applyBlurFilter(to: rampSource, item: pixelHigh) else {
            XCTFail("Expected Pixelate blurred outputs across opacity levels")
            return
        }
        let runLow = maxConstantRunLength(in: pImgLow, row: 80)
        let runMid = maxConstantRunLength(in: pImgMid, row: 80)
        let runHigh = maxConstantRunLength(in: pImgHigh, row: 80)
        XCTAssertLessThan(runLow, runMid)
        XCTAssertLessThan(runMid, runHigh)
    }

    func testScreenCaptureWindowExclusionAndDisplayResolution() {
        let context = ScreenCaptureManager.WindowExclusionContext(
            currentPID: 4242,
            excludingWindowID: 900,
            normalWindowLayer: 0
        )

        let ownSettingsWindow = ScreenCaptureManager.WindowExclusionCandidate(windowID: 101, owningPID: 4242, windowLayer: 0)
        XCTAssertFalse(ScreenCaptureManager.shouldExcludeWindow(ownSettingsWindow, context: context))

        let ownSubNormalWindow = ScreenCaptureManager.WindowExclusionCandidate(windowID: 102, owningPID: 4242, windowLayer: -1)
        XCTAssertFalse(ScreenCaptureManager.shouldExcludeWindow(ownSubNormalWindow, context: context))

        let ownFloatingOverlay = ScreenCaptureManager.WindowExclusionCandidate(windowID: 103, owningPID: 4242, windowLayer: 1000)
        XCTAssertTrue(ScreenCaptureManager.shouldExcludeWindow(ownFloatingOverlay, context: context))

        let explicitExcluded = ScreenCaptureManager.WindowExclusionCandidate(windowID: 900, owningPID: 9999, windowLayer: 0)
        XCTAssertTrue(ScreenCaptureManager.shouldExcludeWindow(explicitExcluded, context: context))

        let otherAppNormal = ScreenCaptureManager.WindowExclusionCandidate(windowID: 205, owningPID: 7777, windowLayer: 0)
        XCTAssertFalse(ScreenCaptureManager.shouldExcludeWindow(otherAppNormal, context: context))

        let otherAppFloating = ScreenCaptureManager.WindowExclusionCandidate(windowID: 206, owningPID: 7777, windowLayer: 25)
        XCTAssertFalse(ScreenCaptureManager.shouldExcludeWindow(otherAppFloating, context: context))

        XCTAssertNil(ScreenCaptureManager.resolveTargetDisplayID(availableDisplayIDs: [], preferredDisplayID: 10))
        XCTAssertEqual(
            ScreenCaptureManager.resolveTargetDisplayID(availableDisplayIDs: [10, 20, 30], preferredDisplayID: 20),
            20
        )
        XCTAssertEqual(
            ScreenCaptureManager.resolveTargetDisplayID(availableDisplayIDs: [10, 20, 30], preferredDisplayID: 99),
            10
        )
        XCTAssertEqual(
            ScreenCaptureManager.resolveTargetDisplayID(availableDisplayIDs: [10, 20], preferredDisplayID: nil),
            10
        )
    }

    func testBackdropGlassTiersAppearanceSyncAndTintedOpaqueExport() {
        XCTAssertEqual(BackdropGlassTier.from(opacity: 0.10), .ultraThin)
        XCTAssertEqual(BackdropGlassTier.from(opacity: 0.25), .ultraThin)
        XCTAssertEqual(BackdropGlassTier.from(opacity: 0.35), .thin)
        XCTAssertEqual(BackdropGlassTier.from(opacity: 0.55), .regular)
        XCTAssertEqual(BackdropGlassTier.from(opacity: 0.75), .thick)
        XCTAssertEqual(BackdropGlassTier.from(opacity: 0.95), .ultraThick)
        XCTAssertEqual(BackdropGlassTier.from(opacity: 1.00), .ultraThick)
        XCTAssertEqual(BackdropGlassTier.from(opacity: .nan), .regular)

        let settings = AppSettings(defaults: testDefaults)
        settings.annotateToolIndicator = false
        settings.whiteboardEnabled = false
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let view = AnnotateCanvasView(
            frame: NSRect(x: 0, y: 0, width: 240, height: 200),
            canvasState: canvas,
            settings: settings,
            shortcutManager: shortcuts
        )

        let blurItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 40, y: 40),
            endPoint: CGPoint(x: 200, y: 160),
            strokeColor: .blue,
            lineWeight: 6.0,
            blurStyle: .gaussian,
            blurOpacity: 0.20,
            blurTintColor: nil
        )
        canvas.annotations = [blurItem]
        view.syncBackdropBlurViews()
        guard let backdrop = view.backdropBlurViews[blurItem.id] else {
            XCTFail("Expected mounted BackdropBlurRegionView")
            return
        }
        XCTAssertEqual(backdrop.glassTier, .ultraThin)
        XCTAssertEqual(backdrop.opacityLevel, 0.20, accuracy: 1e-6)
        XCTAssertNil(backdrop.tintColor)

        canvas.selectedIDs = [blurItem.id]
        canvas.updateSelectedBlurOpacity(0.92)
        view.syncBackdropBlurViews()
        XCTAssertEqual(backdrop.glassTier, .ultraThick)
        XCTAssertEqual(backdrop.opacityLevel, 0.92, accuracy: 1e-6)

        canvas.updateSelectedBlurTintColor(.red)
        view.syncBackdropBlurViews()
        XCTAssertEqual(backdrop.tintColor, .red)

        guard let redFallbackPNG = Screenshotter.renderViewToPNGData(view),
              let redFallbackCG = NSBitmapImageRep(data: redFallbackPNG)?.cgImage,
              let redFallbackPx = rgbaPixel(in: redFallbackCG, at: (x: redFallbackCG.width / 2, y: redFallbackCG.height / 2)) else {
            XCTFail("Expected opaque red-tinted fallback PNG")
            return
        }
        XCTAssertEqual(redFallbackPx.a, 255)
        XCTAssertGreaterThan(Int(redFallbackPx.r), Int(redFallbackPx.g) + 80)
        XCTAssertGreaterThan(Int(redFallbackPx.r), Int(redFallbackPx.b) + 80)

        canvas.updateSelectedBlurTintColor(.green)
        view.syncBackdropBlurViews()
        guard let greenFallbackPNG = Screenshotter.renderViewToPNGData(view),
              let greenFallbackCG = NSBitmapImageRep(data: greenFallbackPNG)?.cgImage,
              let greenFallbackPx = rgbaPixel(in: greenFallbackCG, at: (x: greenFallbackCG.width / 2, y: greenFallbackCG.height / 2)) else {
            XCTFail("Expected opaque green-tinted fallback PNG")
            return
        }
        XCTAssertEqual(greenFallbackPx.a, 255)
        XCTAssertGreaterThan(Int(greenFallbackPx.g), Int(greenFallbackPx.r) + 80)
        XCTAssertGreaterThan(Int(greenFallbackPx.g), Int(greenFallbackPx.b) + 80)

        view.regionCaptureProvider = { _ in
            self.makeSolidGrayImage(size: 160, gray: 120)
        }
        canvas.updateSelectedBlurTintColor(nil)
        canvas.updateSelectedBlurOpacity(0.30)
        view.clearBlurCache()
        guard let neutralLowPNG = Screenshotter.renderViewToPNGData(view),
              let neutralLowCG = NSBitmapImageRep(data: neutralLowPNG)?.cgImage,
              let neutralLowPx = rgbaPixel(in: neutralLowCG, at: (x: neutralLowCG.width / 2, y: neutralLowCG.height / 2)) else {
            XCTFail("Expected captured neutral low-opacity PNG")
            return
        }

        canvas.updateSelectedBlurOpacity(1.00)
        view.clearBlurCache()
        guard let neutralHighPNG = Screenshotter.renderViewToPNGData(view),
              let neutralHighCG = NSBitmapImageRep(data: neutralHighPNG)?.cgImage,
              let neutralHighPx = rgbaPixel(in: neutralHighCG, at: (x: neutralHighCG.width / 2, y: neutralHighCG.height / 2)) else {
            XCTFail("Expected captured neutral high-opacity PNG")
            return
        }
        XCTAssertEqual(neutralLowPx.a, 255)
        XCTAssertEqual(neutralHighPx.a, 255)
        XCTAssertGreaterThan(neutralHighPx.r, neutralLowPx.r)

        canvas.updateSelectedBlurOpacity(0.85)
        canvas.updateSelectedBlurTintColor(.red)
        view.clearBlurCache()
        guard let redCapturedPNG = Screenshotter.renderViewToPNGData(view),
              let redCapturedCG = NSBitmapImageRep(data: redCapturedPNG)?.cgImage,
              let redCapturedPx = rgbaPixel(in: redCapturedCG, at: (x: redCapturedCG.width / 2, y: redCapturedCG.height / 2)) else {
            XCTFail("Expected captured red-tinted PNG")
            return
        }
        XCTAssertEqual(redCapturedPx.a, 255)
        XCTAssertGreaterThan(Int(redCapturedPx.r), Int(redCapturedPx.g) + 60)
        XCTAssertGreaterThan(Int(redCapturedPx.r), Int(redCapturedPx.b) + 60)
    }

    private func makeHorizontalGradientImage(size: Int) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        let denom = max(1, size - 1)
        for y in 0..<size {
            for x in 0..<size {
                let offset = (y * size + x) * 4
                let value = UInt8((x * 255) / denom)
                bytes[offset] = value
                bytes[offset + 1] = value
                bytes[offset + 2] = value
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

    private func makeSolidGrayImage(size: Int, gray: UInt8) -> CGImage? {
        var bytes = [UInt8](repeating: gray, count: size * size * 4)
        for idx in stride(from: 3, to: bytes.count, by: 4) {
            bytes[idx] = 255
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

    private func maxConstantRunLength(in image: CGImage, row: Int) -> Int {
        var maxRun = 0
        var currentRun = 0
        var previous: (r: UInt8, g: UInt8, b: UInt8)?
        let startX = min(20, max(0, image.width - 1))
        let endX = max(startX, image.width - 20)
        for x in startX..<endX {
            guard let px = rgbaPixel(in: image, at: (x: x, y: row)) else { continue }
            let matchesPrevious: Bool
            if let prev = previous {
                let sameRG = prev.r == px.r && prev.g == px.g
                matchesPrevious = sameRG && prev.b == px.b
            } else {
                matchesPrevious = false
            }
            if matchesPrevious {
                currentRun += 1
            } else {
                currentRun = 1
                previous = (px.r, px.g, px.b)
            }
            if currentRun > maxRun {
                maxRun = currentRun
            }
        }
        return maxRun
    }

    private struct SyntheticMouseSpec {
        var type: NSEvent.EventType
        var location: CGPoint
        var modifiers: NSEvent.ModifierFlags = []
        var clickCount: Int = 1
    }

    private final class SyntheticTouch: NSTouch, @unchecked Sendable {
        var stubIdentity: NSString = "touch-0"
        var stubPhase: NSTouch.Phase = .began
        var stubNormalizedPosition: NSPoint = .zero

        override var identity: any NSObjectProtocol & NSCopying { stubIdentity }
        override var phase: NSTouch.Phase { stubPhase }
        override var normalizedPosition: NSPoint { stubNormalizedPosition }
        override var hash: Int { ObjectIdentifier(self).hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            self === (object as AnyObject)
        }
    }

    private final class SyntheticTrackpadEvent: NSEvent {
        var stubMagnification: CGFloat = 0
        var stubRotation: Float = 0
        var stubPhase: NSEvent.Phase = []
        var stubTouches: Set<NSTouch> = []

        override var magnification: CGFloat { stubMagnification }
        override var rotation: Float { stubRotation }
        override var phase: NSEvent.Phase { stubPhase }

        override func touches(matching phase: NSTouch.Phase, in view: NSView?) -> Set<NSTouch> {
            Set(stubTouches.filter { !phase.intersection($0.phase).isEmpty })
        }
    }

    private func makeMouseEvent(_ spec: SyntheticMouseSpec, in window: NSWindow?) -> NSEvent {
        guard let event = NSEvent.mouseEvent(
            with: spec.type,
            location: spec.location,
            modifierFlags: spec.modifiers,
            timestamp: 1.0,
            windowNumber: window?.windowNumber ?? 0,
            context: nil,
            eventNumber: 1,
            clickCount: spec.clickCount,
            pressure: 1.0
        ) else {
            fatalError("Failed to create synthetic mouse event")
        }
        return event
    }

    private func makeCanvasHarness() -> (window: NSWindow, view: AnnotateCanvasView, canvas: AnnotationCanvasState, settings: AppSettings) {
        let settings = AppSettings(defaults: testDefaults)
        settings.annotateToolIndicator = false
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let frame = NSRect(x: 0, y: 0, width: 420, height: 360)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let view = AnnotateCanvasView(
            frame: frame,
            canvasState: canvas,
            settings: settings,
            shortcutManager: shortcuts
        )
        window.contentView = view
        return (window, view, canvas, settings)
    }

    func testDirectMouseDragMovesTextAndSelectedShapesWithoutCommandAndCoalescesUndo() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings

        settings.currentDrawMode = .text
        let createPoint = CGPoint(x: 80, y: 120)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: createPoint), in: window))
        XCTAssertNotNil(view.activeTextField)
        view.activeTextField?.stringValue = "Draggable Note"
        view.commitActiveTextEditing()

        XCTAssertEqual(canvas.annotations.count, 1)
        let textID = canvas.annotations[0].id
        let initialCenter = canvas.annotations[0].textCenter
        let undoCountAfterCreate = canvas.undoStack.count

        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: initialCenter), in: window))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: initialCenter), in: window))
        XCTAssertEqual(canvas.selectedIDs, [textID])
        XCTAssertNil(view.activeTextField)
        XCTAssertEqual(canvas.undoStack.count, undoCountAfterCreate)

        let originalOrigin = canvas.annotations[0].startPoint
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: initialCenter), in: window))
        for step in 1...5 {
            let dragPoint = CGPoint(
                x: initialCenter.x + CGFloat(step * 12),
                y: initialCenter.y + CGFloat(step * 6)
            )
            view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: dragPoint), in: window))
        }
        let finalDragPoint = CGPoint(x: initialCenter.x + 60, y: initialCenter.y + 30)
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: finalDragPoint), in: window))

        XCTAssertNil(view.activeTextField)
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations[0].startPoint.x, originalOrigin.x + 60, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.y, originalOrigin.y + 30, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint, canvas.annotations[0].startPoint)
        XCTAssertEqual(canvas.annotations[0].points, [canvas.annotations[0].startPoint])
        XCTAssertEqual(canvas.undoStack.count, undoCountAfterCreate + 1)

        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].startPoint.x, originalOrigin.x, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.y, originalOrigin.y, accuracy: 1e-6)
        canvas.redo()
        XCTAssertEqual(canvas.annotations[0].startPoint.x, originalOrigin.x + 60, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.y, originalOrigin.y + 30, accuracy: 1e-6)

        settings.currentDrawMode = .rectangle
        let rectItem = AnnotationItem(
            mode: .rectangle,
            points: [CGPoint(x: 240, y: 200), CGPoint(x: 320, y: 260)],
            startPoint: CGPoint(x: 240, y: 200),
            endPoint: CGPoint(x: 320, y: 260),
            isFilled: true,
            strokeColor: .green,
            lineWeight: 4.0
        )
        canvas.annotations.append(rectItem)

        let rectHitPoint = CGPoint(x: 280, y: 230)
        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: rectHitPoint, modifiers: [.command]),
                in: window
            )
        )
        view.mouseUp(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseUp, location: rectHitPoint, modifiers: [.command]),
                in: window
            )
        )
        XCTAssertEqual(canvas.selectedIDs, [rectItem.id])

        let undoBeforeRectDrag = canvas.undoStack.count
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: rectHitPoint), in: window))
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: 295, y: 240)),
                in: window
            )
        )
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: 310, y: 250)),
                in: window
            )
        )
        view.mouseUp(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseUp, location: CGPoint(x: 310, y: 250)),
                in: window
            )
        )
        XCTAssertNil(canvas.activeDraft)
        XCTAssertEqual(canvas.annotations.count, 2)
        XCTAssertEqual(canvas.annotations[1].startPoint, CGPoint(x: 270, y: 220))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeRectDrag + 1)

        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: CGPoint(x: 250, y: 200), modifiers: [.command]),
                in: window
            )
        )
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: 360, y: 300), modifiers: [.command]),
                in: window
            )
        )
        view.mouseUp(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseUp, location: CGPoint(x: 360, y: 300), modifiers: [.command]),
                in: window
            )
        )
        XCTAssertEqual(canvas.selectedIDs, [rectItem.id])

        let undoBeforeStandalone = canvas.undoStack.count
        canvas.moveSelectedAnnotations(by: CGSize(width: 5, height: -5))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeStandalone + 1)
    }

    func testDoubleClickTextOpensPrefilledInlineEditorAndPreservesMetadataOnCommit() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings

        settings.currentDrawMode = .text
        settings.annotateFontSize = 18.0
        settings.selectFavoriteColor(index: 4)

        let customID = UUID()
        let origin = CGPoint(x: 90, y: 110)
        let savedRotation = Double.pi / 6.0
        let initialItem = AnnotationItem(
            id: customID,
            mode: .text,
            points: [origin],
            startPoint: origin,
            endPoint: origin,
            strokeColor: .orange,
            lineWeight: 2.0,
            text: "Original Text",
            fontName: AnnotateFontOption.menlo.fontName,
            fontSize: 38.0,
            rotationRadians: savedRotation
        )
        canvas.annotations = [initialItem]

        let centerHit = initialItem.textCenter
        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: centerHit, clickCount: 2),
                in: window
            )
        )
        guard let activeField = view.activeTextField else {
            XCTFail("Expected activeTextField on double-click")
            return
        }
        XCTAssertEqual(view.editingAnnotationID, customID)
        XCTAssertEqual(canvas.selectedIDs, [customID])
        XCTAssertEqual(activeField.stringValue, "Original Text")
        XCTAssertEqual(activeField.textColor, RGBColor.orange.nsColor)
        XCTAssertEqual(Double(activeField.font?.pointSize ?? 0), 38.0, accuracy: 1e-6)
        XCTAssertEqual(activeField.frame.origin, origin)

        activeField.stringValue = "Updated Copy"
        view.commitActiveTextEditing()

        XCTAssertEqual(canvas.annotations.count, 1)
        let updated = canvas.annotations[0]
        XCTAssertEqual(updated.id, customID)
        XCTAssertEqual(updated.text, "Updated Copy")
        XCTAssertEqual(updated.strokeColor, .orange)
        XCTAssertEqual(updated.fontName, AnnotateFontOption.menlo.fontName)
        XCTAssertEqual(updated.fontSize, 38.0, accuracy: 1e-6)
        XCTAssertEqual(updated.startPoint, origin)
        XCTAssertEqual(updated.rotationRadians, savedRotation, accuracy: 1e-9)

        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: updated.textCenter, clickCount: 2),
                in: window
            )
        )
        XCTAssertNotNil(view.activeTextField)
        settings.setCustomStrokeColor(.green)
        view.activeTextField?.stringValue = "Green Copy"
        view.commitActiveTextEditing()

        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations[0].id, customID)
        XCTAssertEqual(canvas.annotations[0].text, "Green Copy")
        XCTAssertEqual(canvas.annotations[0].strokeColor, .green)
        XCTAssertEqual(canvas.annotations[0].fontSize, 38.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].rotationRadians, savedRotation, accuracy: 1e-9)
    }

    func testTextLayoutBoundsCornerScaleHandlesClampCenterPreservationAndPinchZoom() {
        let smallText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 40, y: 50),
            endPoint: CGPoint(x: 40, y: 50),
            strokeColor: .white,
            text: "Scale Sample",
            fontSize: 16.0
        )
        let largeText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 40, y: 50),
            endPoint: CGPoint(x: 40, y: 50),
            strokeColor: .white,
            text: "Scale Sample",
            fontSize: 48.0
        )
        let emptyText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 15, y: 25),
            endPoint: CGPoint(x: 15, y: 25),
            strokeColor: .white,
            text: "",
            fontSize: 12.0
        )
        XCTAssertGreaterThan(largeText.textLayoutRect.width, smallText.textLayoutRect.width * 2.2)
        XCTAssertGreaterThan(largeText.textLayoutRect.height, smallText.textLayoutRect.height * 2.2)
        XCTAssertGreaterThanOrEqual(emptyText.textLayoutRect.width, 24.0)
        XCTAssertGreaterThanOrEqual(emptyText.textLayoutRect.height, 20.0)
        XCTAssertEqual(emptyText.boundingRect, emptyText.textLayoutRect)

        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas

        let item = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 150, y: 150),
            endPoint: CGPoint(x: 150, y: 150),
            strokeColor: .white,
            text: "Corner Scale",
            fontSize: 24.0
        )
        canvas.annotations = [item]
        canvas.selectedIDs = [item.id]

        let initialCenter = item.textCenter
        let cornerHandle = item.worldTextScaleHandleCenters[2]
        let vecX = cornerHandle.x - initialCenter.x
        let vecY = cornerHandle.y - initialCenter.y
        let undoBeforeScale = canvas.undoStack.count

        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: cornerHandle), in: window))
        let midHandle = CGPoint(x: initialCenter.x + vecX * 1.5, y: initialCenter.y + vecY * 1.5)
        let doubleHandle = CGPoint(x: initialCenter.x + vecX * 2.0, y: initialCenter.y + vecY * 2.0)
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: midHandle), in: window))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: doubleHandle), in: window))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: doubleHandle), in: window))

        XCTAssertEqual(canvas.annotations[0].fontSize, 48.0, accuracy: 0.25)
        XCTAssertEqual(canvas.annotations[0].textCenter.x, initialCenter.x, accuracy: 1.0)
        XCTAssertEqual(canvas.annotations[0].textCenter.y, initialCenter.y, accuracy: 1.0)
        XCTAssertEqual(canvas.annotations[0].endPoint, canvas.annotations[0].startPoint)
        XCTAssertEqual(canvas.annotations[0].points, [canvas.annotations[0].startPoint])
        XCTAssertEqual(canvas.undoStack.count, undoBeforeScale + 1)

        let shrinkHandle = canvas.annotations[0].worldTextScaleHandleCenters[2]
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: shrinkHandle), in: window))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: initialCenter), in: window))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: initialCenter), in: window))
        XCTAssertEqual(canvas.annotations[0].fontSize, 8.0, accuracy: 1e-6)

        let growHandle = canvas.annotations[0].worldTextScaleHandleCenters[2]
        let farOut = CGPoint(x: initialCenter.x + 4000, y: initialCenter.y + 4000)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: growHandle), in: window))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: farOut), in: window))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: farOut), in: window))
        XCTAssertEqual(canvas.annotations[0].fontSize, 200.0, accuracy: 1e-6)

        canvas.scaleTextAnnotation(item.id, toFontSize: 30.0)
        let undoBeforePinch = canvas.undoStack.count
        let pinchBegan = SyntheticTrackpadEvent()
        pinchBegan.stubPhase = .began
        pinchBegan.stubMagnification = 0.20
        let pinchChanged = SyntheticTrackpadEvent()
        pinchChanged.stubPhase = .changed
        pinchChanged.stubMagnification = 0.25
        let pinchEnded = SyntheticTrackpadEvent()
        pinchEnded.stubPhase = .ended
        pinchEnded.stubMagnification = 0.0

        view.magnify(with: pinchBegan)
        view.magnify(with: pinchChanged)
        view.magnify(with: pinchEnded)
        XCTAssertEqual(canvas.annotations[0].fontSize, 45.0, accuracy: 0.25)
        XCTAssertEqual(canvas.undoStack.count, undoBeforePinch + 1)

        let singlePinch = SyntheticTrackpadEvent()
        singlePinch.stubPhase = []
        singlePinch.stubMagnification = 0.10
        view.magnify(with: singlePinch)
        XCTAssertEqual(canvas.undoStack.count, undoBeforePinch + 2)
    }

    func testBracketShortcutsAndToolbarButtonsAdjustTextSizeAndShowToast() {
        let harness = makeCanvasHarness()
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings

        var reportedTextSizes: [Double] = []
        view.onTextSizeChanged = { reportedTextSizes.append($0) }

        settings.currentDrawMode = .text
        settings.annotateFontSize = 24.0
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(settings.annotateFontSize, 26.0, accuracy: 1e-6)
        XCTAssertEqual(reportedTextSizes.last ?? 0, 26.0, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(settings.annotateFontSize, 24.0, accuracy: 1e-6)
        XCTAssertEqual(reportedTextSizes.last ?? 0, 24.0, accuracy: 1e-6)

        let textItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 100, y: 100),
            endPoint: CGPoint(x: 100, y: 100),
            strokeColor: .white,
            text: "Shortcut Target",
            fontSize: 20.0
        )
        canvas.annotations = [textItem]
        canvas.selectedIDs = [textItem.id]
        settings.currentDrawMode = .rectangle

        let undoBeforeBracket = canvas.undoStack.count
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].fontSize, 22.0, accuracy: 1e-6)
        XCTAssertEqual(settings.annotateFontSize, 22.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeBracket + 1)

        var toolbarReportedSizes: [Double] = []
        let controls = AnnotateControlsView(
            settings: settings,
            canvasState: canvas,
            onTextSizeChanged: { toolbarReportedSizes.append($0) }
        )
        XCTAssertTrue(controls.isAdjustingTextSize)
        XCTAssertEqual(controls.displayedTextFontSize, 22.0, accuracy: 1e-6)

        controls.increaseTextSize()
        XCTAssertEqual(canvas.annotations[0].fontSize, 24.0, accuracy: 1e-6)
        XCTAssertEqual(toolbarReportedSizes.last ?? 0, 24.0, accuracy: 1e-6)

        controls.decreaseTextSize()
        XCTAssertEqual(canvas.annotations[0].fontSize, 22.0, accuracy: 1e-6)
        XCTAssertEqual(toolbarReportedSizes.last ?? 0, 22.0, accuracy: 1e-6)

        canvas.scaleTextAnnotation(textItem.id, toFontSize: 8.0)
        controls.decreaseTextSize()
        XCTAssertEqual(canvas.annotations[0].fontSize, 8.0, accuracy: 1e-6)
        XCTAssertEqual(settings.annotateFontSize, 10.0, accuracy: 1e-6)

        canvas.scaleTextAnnotation(textItem.id, toFontSize: 200.0)
        controls.increaseTextSize()
        XCTAssertEqual(canvas.annotations[0].fontSize, 200.0, accuracy: 1e-6)
        XCTAssertEqual(settings.annotateFontSize, 96.0, accuracy: 1e-6)

        let rectItem = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 50, y: 50),
            strokeColor: .red
        )
        canvas.annotations.append(rectItem)
        canvas.selectedIDs = [rectItem.id]
        XCTAssertFalse(controls.isAdjustingTextSize)

        let shortcuts = ShortcutManager(defaults: testDefaults)
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: canvas)
        overlay.showAnnotation()
        canvas.selectedIDs = [textItem.id]
        canvas.scaleTextAnnotation(textItem.id, toFontSize: 30.0)
        XCTAssertEqual(overlay.canvasView?.handleKeyCommand(keyCode: 0x1E, modifiers: 0), true)
        XCTAssertEqual(overlay.toastController.currentMessage, "Text Size: 32 pt")
        overlay.hideAnnotation()
    }

    func testTextRotationHandleDragShiftSnapTrackpadRotateAndRotatedHitTesting() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas

        let banner = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 110, y: 160),
            endPoint: CGPoint(x: 110, y: 160),
            strokeColor: .white,
            text: "Wide Rotatable Text Banner",
            fontSize: 28.0
        )
        canvas.annotations = [banner]
        canvas.selectedIDs = [banner.id]

        let selectionBox = banner.textSelectionBox
        XCTAssertEqual(banner.localTextRotationHandleCenter.x, selectionBox.midX, accuracy: 1e-6)
        XCTAssertEqual(banner.localTextRotationHandleCenter.y, selectionBox.maxY + 22.0, accuracy: 1e-6)

        let center = banner.textCenter
        let startHandle = banner.worldTextRotationHandleCenter
        let radius = hypot(startHandle.x - center.x, startHandle.y - center.y)
        let startAngle = atan2(Double(startHandle.y - center.y), Double(startHandle.x - center.x))
        let undoBeforeRotate = canvas.undoStack.count

        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: startHandle), in: window))
        let midAngle = startAngle + Double.pi / 8.0
        let endAngle = startAngle + Double.pi / 4.0
        let midPoint = CGPoint(
            x: center.x + CGFloat(cos(midAngle)) * radius,
            y: center.y + CGFloat(sin(midAngle)) * radius
        )
        let endPoint = CGPoint(
            x: center.x + CGFloat(cos(endAngle)) * radius,
            y: center.y + CGFloat(sin(endAngle)) * radius
        )
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: midPoint), in: window))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: endPoint), in: window))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: endPoint), in: window))

        XCTAssertEqual(canvas.annotations[0].rotationRadians, Double.pi / 4.0, accuracy: 1e-3)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeRotate + 1)

        canvas.setTextRotation(0.0, for: banner.id)
        let resetHandle = canvas.annotations[0].worldTextRotationHandleCenter
        let rawSnapAngle = startAngle + (22.0 * Double.pi / 180.0)
        let snapDragPoint = CGPoint(
            x: center.x + CGFloat(cos(rawSnapAngle)) * radius,
            y: center.y + CGFloat(sin(rawSnapAngle)) * radius
        )
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: resetHandle), in: window))
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: snapDragPoint, modifiers: [.shift]),
                in: window
            )
        )
        view.mouseUp(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseUp, location: snapDragPoint, modifiers: [.shift]),
                in: window
            )
        )
        XCTAssertEqual(canvas.annotations[0].rotationRadians, Double.pi / 12.0, accuracy: 1e-6)

        let unrotatedRect = banner.textLayoutRect
        XCTAssertGreaterThan(unrotatedRect.width, unrotatedRect.height * 3.0)
        canvas.setTextRotation(Double.pi / 2.0, for: banner.id)
        let rotatedItem = canvas.annotations[0]
        let rotatedBounds = rotatedItem.boundingRect
        XCTAssertEqual(rotatedBounds.width, unrotatedRect.height, accuracy: 1e-3)
        XCTAssertEqual(rotatedBounds.height, unrotatedRect.width, accuracy: 1e-3)

        let verticalArmPoint = CGPoint(
            x: center.x,
            y: center.y + unrotatedRect.width * 0.40
        )
        let vacatedHorizontalPoint = CGPoint(
            x: center.x + unrotatedRect.width * 0.45,
            y: center.y
        )
        XCTAssertEqual(canvas.hitTestAnnotation(at: verticalArmPoint), banner.id)
        XCTAssertNil(canvas.hitTestAnnotation(at: vacatedHorizontalPoint))

        let rotatedHandle = rotatedItem.worldTextRotationHandleCenter
        XCTAssertEqual(rotatedHandle.x, center.x - (unrotatedRect.height * 0.5 + 26.0), accuracy: 1.0)
        XCTAssertEqual(rotatedHandle.y, center.y, accuracy: 1.0)

        let undoBeforeTrackpadRotate = canvas.undoStack.count
        let rotBegan = SyntheticTrackpadEvent()
        rotBegan.stubPhase = .began
        rotBegan.stubRotation = 15.0
        let rotChanged = SyntheticTrackpadEvent()
        rotChanged.stubPhase = .changed
        rotChanged.stubRotation = 15.0
        let rotEnded = SyntheticTrackpadEvent()
        rotEnded.stubPhase = .ended
        rotEnded.stubRotation = 0.0

        view.rotate(with: rotBegan)
        view.rotate(with: rotChanged)
        view.rotate(with: rotEnded)
        XCTAssertEqual(
            canvas.annotations[0].rotationRadians,
            Double.pi / 2.0 + (30.0 * Double.pi / 180.0),
            accuracy: 1e-4
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeTrackpadRotate + 1)
    }

    func testTextRotationSessionRoundTripLegacyJSONDecodeAndNonFiniteSanitization() throws {
        let legacyJSON = """
        [
          {
            "id": "5621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "text",
            "points": [[60, 80]],
            "startPoint": [60, 80],
            "endPoint": [60, 80],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 1, "green": 1, "blue": 1, "alpha": 1},
            "lineWeight": 2,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "Legacy Note",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 28
          }
        ]
        """.data(using: .utf8)!

        let decodedLegacy = try JSONDecoder().decode([AnnotationItem].self, from: legacyJSON)
        XCTAssertEqual(decodedLegacy.count, 1)
        XCTAssertEqual(decodedLegacy[0].rotationRadians, 0.0, accuracy: 1e-9)

        let canvas = AnnotationCanvasState()
        XCTAssertTrue(canvas.importSessionData(legacyJSON))
        XCTAssertEqual(canvas.annotations[0].rotationRadians, 0.0, accuracy: 1e-9)

        canvas.setTextRotation(Double.pi / 3.0, for: canvas.annotations[0].id)
        guard let exported = canvas.exportSessionData() else {
            XCTFail("Expected exported session JSON data")
            return
        }

        let restoredCanvas = AnnotationCanvasState()
        XCTAssertTrue(restoredCanvas.importSessionData(exported))
        XCTAssertEqual(restoredCanvas.annotations.count, 1)
        XCTAssertEqual(restoredCanvas.annotations[0].rotationRadians, Double.pi / 3.0, accuracy: 1e-9)

        XCTAssertEqual(AnnotationCanvasState.sanitizeRotationRadians(.nan), 0.0, accuracy: 1e-9)
        XCTAssertEqual(AnnotationCanvasState.sanitizeRotationRadians(.infinity), 0.0, accuracy: 1e-9)
        XCTAssertEqual(AnnotationCanvasState.sanitizeRotationRadians(-.infinity), 0.0, accuracy: 1e-9)

        let largeRotationJSON = """
        [
          {
            "id": "6621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "text",
            "points": [[50, 70]],
            "startPoint": [50, 70],
            "endPoint": [50, 70],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 1, "green": 1, "blue": 1, "alpha": 1},
            "lineWeight": 2,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "Wrapped Angle",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 24,
            "rotationRadians": 100.0
          }
        ]
        """.data(using: .utf8)!
        XCTAssertTrue(restoredCanvas.importSessionData(largeRotationJSON))
        let expectedWrapped = (100.0).remainder(dividingBy: 2.0 * Double.pi)
        XCTAssertEqual(restoredCanvas.annotations[0].rotationRadians, expectedWrapped, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(abs(restoredCanvas.annotations[0].rotationRadians), Double.pi)

        var nonFiniteItem = restoredCanvas.annotations[0]
        nonFiniteItem.rotationRadians = .nan
        XCTAssertEqual(nonFiniteItem.effectiveRotationRadians, 0.0, accuracy: 1e-9)
        XCTAssertTrue(nonFiniteItem.boundingRect.width.isFinite)
        XCTAssertTrue(nonFiniteItem.boundingRect.height.isFinite)
    }

    func testSelectedRotatedTextRendersBlueLightBlueAndWhiteHandlesWithoutPurple() {
        let harness = makeCanvasHarness()
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        settings.isWhiteboardActive = false
        settings.dimScreenOnAnnotate = false

        let rotatedText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 150, y: 150),
            endPoint: CGPoint(x: 150, y: 150),
            strokeColor: .white,
            text: "Theme Check",
            fontSize: 32.0,
            rotationRadians: Double.pi / 6.0
        )
        canvas.annotations = [rotatedText]
        canvas.selectedIDs = [rotatedText.id]

        guard let pngData = Screenshotter.renderViewToPNGData(view),
              let cgImage = NSBitmapImageRep(data: pngData)?.cgImage else {
            XCTFail("Expected rendered PNG for selected rotated text")
            return
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            XCTFail("Expected sRGB color space")
            return
        }

        let imgWidth = cgImage.width
        let imgHeight = cgImage.height
        var bytes = [UInt8](repeating: 0, count: imgWidth * imgHeight * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let didRasterize = bytes.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: imgWidth,
                height: imgHeight,
                bitsPerComponent: 8,
                bytesPerRow: imgWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
            return true
        }
        XCTAssertTrue(didRasterize)

        let scaleX = Double(imgWidth) / Double(max(1.0, view.bounds.width))
        let scaleY = Double(imgHeight) / Double(max(1.0, view.bounds.height))
        let rotHandle = rotatedText.worldTextRotationHandleCenter
        let centerPxX = Int((Double(rotHandle.x) * scaleX).rounded())
        let centerPxY = Int((Double(view.bounds.height - rotHandle.y) * scaleY).rounded())

        var foundWhiteHandleInterior = false
        var foundBlueHandleStroke = false
        let searchRadius = max(6, Int((7.0 * scaleX).rounded()))
        for dy in -searchRadius...searchRadius {
            for dx in -searchRadius...searchRadius {
                let pxX = centerPxX + dx
                let pxY = centerPxY + dy
                let inXBounds = pxX >= 0 && pxX < imgWidth
                let inYBounds = pxY >= 0 && pxY < imgHeight
                guard inXBounds && inYBounds else { continue }
                let offset = (pxY * imgWidth + pxX) * 4
                let r = bytes[offset]
                let g = bytes[offset + 1]
                let b = bytes[offset + 2]
                let a = bytes[offset + 3]
                let isBrightRG = r >= 235 && g >= 235
                let isOpaqueWhite = b >= 235 && a >= 245
                if isBrightRG && isOpaqueWhite {
                    foundWhiteHandleInterior = true
                }
                let isBlueDominantOverRed = Int(b) > Int(r) + 60
                let isVisibleBlue = a >= 120 && b >= 150
                if isBlueDominantOverRed && isVisibleBlue {
                    foundBlueHandleStroke = true
                }
            }
        }
        XCTAssertTrue(foundWhiteHandleInterior)
        XCTAssertTrue(foundBlueHandleStroke)

        var foundPurplePixel = false
        for idx in stride(from: 0, to: bytes.count, by: 4) {
            let r = bytes[idx]
            let g = bytes[idx + 1]
            let b = bytes[idx + 2]
            let a = bytes[idx + 3]
            let hasRedExcessOverGreen = Int(r) > Int(g) + 30
            let hasPurpleBlueChannel = b > 100 && a > 40
            if hasRedExcessOverGreen && hasPurpleBlueChannel {
                foundPurplePixel = true
            }
        }
        XCTAssertFalse(foundPurplePixel)
    }

    func testRemainingCornerScaleHandlesAndRotatedTextCornerScaling() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas

        for cornerIndex in [0, 1, 3] {
            let item = AnnotationItem(
                mode: .text,
                startPoint: CGPoint(x: 160, y: 150),
                endPoint: CGPoint(x: 160, y: 150),
                strokeColor: .white,
                text: "Corner \(cornerIndex)",
                fontSize: 20.0
            )
            canvas.annotations = [item]
            canvas.selectedIDs = [item.id]

            let initialCenter = item.textCenter
            let handle = item.worldTextScaleHandleCenters[cornerIndex]
            let dx = handle.x - initialCenter.x
            let dy = handle.y - initialCenter.y
            let scaledTarget = CGPoint(x: initialCenter.x + dx * 1.5, y: initialCenter.y + dy * 1.5)

            view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: handle), in: window))
            view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: scaledTarget), in: window))
            view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: scaledTarget), in: window))

            XCTAssertEqual(canvas.annotations[0].fontSize, 30.0, accuracy: 0.25)
            XCTAssertEqual(canvas.annotations[0].textCenter.x, initialCenter.x, accuracy: 1.0)
            XCTAssertEqual(canvas.annotations[0].textCenter.y, initialCenter.y, accuracy: 1.0)
        }

        let initialRotation = Double.pi / 3.0
        let rotatedItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 150, y: 150),
            endPoint: CGPoint(x: 150, y: 150),
            strokeColor: .white,
            text: "Rotated Scale",
            fontSize: 24.0,
            rotationRadians: initialRotation
        )
        canvas.annotations = [rotatedItem]
        canvas.selectedIDs = [rotatedItem.id]

        let rotatedCenter = rotatedItem.textCenter
        let rotatedCorner = rotatedItem.worldTextScaleHandleCenters[1]
        let rDx = rotatedCorner.x - rotatedCenter.x
        let rDy = rotatedCorner.y - rotatedCenter.y
        let doubledCorner = CGPoint(x: rotatedCenter.x + rDx * 2.0, y: rotatedCenter.y + rDy * 2.0)

        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: rotatedCorner), in: window))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: doubledCorner), in: window))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: doubledCorner), in: window))

        XCTAssertEqual(canvas.annotations[0].fontSize, 48.0, accuracy: 0.25)
        XCTAssertEqual(canvas.annotations[0].rotationRadians, initialRotation, accuracy: 1e-9)
        XCTAssertEqual(canvas.annotations[0].textCenter.x, rotatedCenter.x, accuracy: 1.0)
        XCTAssertEqual(canvas.annotations[0].textCenter.y, rotatedCenter.y, accuracy: 1.0)
    }

    func testRotatedTextMarqueeSelectionHitsRotatedBodyAndMissesVacatedCorners() {
        let canvas = AnnotationCanvasState()
        let banner90 = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 100, y: 160),
            endPoint: CGPoint(x: 100, y: 160),
            strokeColor: .white,
            text: "Wide Rotated Marquee Target Banner",
            fontSize: 28.0,
            rotationRadians: Double.pi / 2.0
        )
        canvas.annotations = [banner90]

        let unrotated90 = banner90.textLayoutRect
        let center90 = banner90.textCenter
        let vacatedWingMarquee = CGRect(
            x: center90.x + unrotated90.width * 0.35,
            y: center90.y - 6.0,
            width: 12.0,
            height: 12.0
        )
        XCTAssertTrue(vacatedWingMarquee.intersects(unrotated90))
        canvas.selectAnnotations(in: vacatedWingMarquee)
        XCTAssertTrue(canvas.selectedIDs.isEmpty)

        let rotatedArmMarquee = CGRect(
            x: center90.x - 6.0,
            y: center90.y + unrotated90.width * 0.35,
            width: 12.0,
            height: 12.0
        )
        canvas.selectAnnotations(in: rotatedArmMarquee)
        XCTAssertEqual(canvas.selectedIDs, [banner90.id])

        let banner45 = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 100, y: 160),
            endPoint: CGPoint(x: 100, y: 160),
            strokeColor: .white,
            text: "Wide Rotated Marquee Target Banner",
            fontSize: 28.0,
            rotationRadians: Double.pi / 4.0
        )
        canvas.annotations = [banner45]
        let aabb45 = banner45.boundingRect
        let vacatedTopLeftAABBCorner = CGRect(
            x: aabb45.minX + 2.0,
            y: aabb45.maxY - 12.0,
            width: 10.0,
            height: 10.0
        )
        XCTAssertTrue(vacatedTopLeftAABBCorner.intersects(aabb45))
        canvas.selectAnnotations(in: vacatedTopLeftAABBCorner)
        XCTAssertTrue(canvas.selectedIDs.isEmpty)

        let centerBodyMarquee = CGRect(
            x: banner45.textCenter.x - 5.0,
            y: banner45.textCenter.y - 5.0,
            width: 10.0,
            height: 10.0
        )
        canvas.selectAnnotations(in: centerBodyMarquee)
        XCTAssertEqual(canvas.selectedIDs, [banner45.id])
    }

    func testInlineEditEscapeCancelFreeHandDoubleClickJitterLiveSizeSyncMultiSelectHandlesAndWidthClamp() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings

        let item = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 90, y: 120),
            endPoint: CGPoint(x: 90, y: 120),
            strokeColor: .yellow,
            text: "Keep Original",
            fontSize: 30.0,
            rotationRadians: Double.pi / 8.0
        )
        canvas.annotations = [item]
        canvas.selectedIDs = [item.id]
        let undoCountInitial = canvas.undoStack.count

        settings.currentDrawMode = .freeHand
        let hitCenter = item.textCenter
        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: hitCenter, clickCount: 2),
                in: window
            )
        )
        XCTAssertNotNil(view.activeTextField)

        let jitterA = CGPoint(x: hitCenter.x + 8.0, y: hitCenter.y + 5.0)
        let jitterB = CGPoint(x: hitCenter.x + 16.0, y: hitCenter.y + 10.0)
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: jitterA), in: window))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: jitterB), in: window))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: jitterB), in: window))

        XCTAssertNil(canvas.activeDraft)
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertNotNil(view.activeTextField)

        view.activeTextField?.stringValue = "Discarded Draft"
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x35, modifiers: 0))
        XCTAssertNil(view.activeTextField)
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations[0].text, "Keep Original")
        XCTAssertEqual(canvas.annotations[0].fontSize, 30.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoCountInitial)

        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: canvas.annotations[0].textCenter, clickCount: 2),
                in: window
            )
        )
        XCTAssertNotNil(view.activeTextField)
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)
        controls.increaseTextSize()
        controls.increaseTextSize()
        XCTAssertEqual(Double(view.activeTextField?.font?.pointSize ?? 0), 34.0, accuracy: 1e-6)
        view.activeTextField?.stringValue = "Resized While Editing"
        view.commitActiveTextEditing()
        XCTAssertEqual(canvas.annotations[0].text, "Resized While Editing")
        XCTAssertEqual(canvas.annotations[0].fontSize, 34.0, accuracy: 1e-6)

        canvas.selectedIDs.removeAll()
        settings.currentDrawMode = .text
        settings.annotateFontSize = 22.0
        view.beginInlineTextEditing(at: CGPoint(x: 40, y: 40))
        controls.increaseTextSize()
        XCTAssertEqual(Double(view.activeTextField?.font?.pointSize ?? 0), 24.0, accuracy: 1e-6)
        view.activeTextField?.stringValue = "New Sized Text"
        view.commitActiveTextEditing()
        XCTAssertEqual(canvas.annotations.last?.fontSize ?? 0, 24.0, accuracy: 1e-6)

        let secondShape = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 60, y: 60),
            strokeColor: .blue
        )
        canvas.annotations = [item, secondShape]
        canvas.selectedIDs = [item.id, secondShape.id]
        settings.isWhiteboardActive = false
        settings.dimScreenOnAnnotate = false

        guard let multiPNG = Screenshotter.renderViewToPNGData(view),
              let multiCG = NSBitmapImageRep(data: multiPNG)?.cgImage else {
            XCTFail("Expected rendered PNG for multi-selection")
            return
        }
        let scaleX = Double(multiCG.width) / Double(max(1.0, view.bounds.width))
        let scaleY = Double(multiCG.height) / Double(max(1.0, view.bounds.height))
        let suppressedRotHandle = item.worldTextRotationHandleCenter
        let rotPxX = Int((Double(suppressedRotHandle.x) * scaleX).rounded())
        let rotPxY = Int((Double(view.bounds.height - suppressedRotHandle.y) * scaleY).rounded())
        if let handlePx = rgbaPixel(in: multiCG, at: (x: rotPxX, y: rotPxY)) {
            XCTAssertEqual(handlePx.a, 0)
        } else {
            XCTFail("Expected readable pixel at rotation handle coordinate")
        }

        let wideFrame = NSRect(x: 0, y: 0, width: 2000, height: 900)
        let wideShortcuts = ShortcutManager(defaults: testDefaults)
        let wideView = AnnotateCanvasView(
            frame: wideFrame,
            canvasState: canvas,
            settings: settings,
            shortcutManager: wideShortcuts
        )
        let hugeText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 20, y: 100),
            endPoint: CGPoint(x: 20, y: 100),
            strokeColor: .white,
            text: String(repeating: "W", count: 5000),
            fontSize: 200.0
        )
        canvas.annotations = [hugeText]
        wideView.beginInlineTextEditing(at: hugeText.startPoint, existingID: hugeText.id)
        guard let clampedField = wideView.activeTextField else {
            XCTFail("Expected activeTextField for long single-line text")
            return
        }
        XCTAssertLessThanOrEqual(clampedField.frame.width, 1200.0)
        XCTAssertLessThanOrEqual(clampedField.frame.height, 400.0)
        wideView.cancelActiveTextEditing()
    }

    func testTextHardeningNaNFontSizeNonFiniteDeltaAndPointsRotationNormalizationTextCapAndImportBounds() throws {
        let harness = makeCanvasHarness()
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings

        let nanInitItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 80, y: 90),
            endPoint: CGPoint(x: 80, y: 90),
            strokeColor: .white,
            text: "Safe Init",
            fontSize: .nan,
            rotationRadians: .infinity
        )
        XCTAssertEqual(nanInitItem.fontSize, 24.0, accuracy: 1e-6)
        XCTAssertEqual(nanInitItem.rotationRadians, 0.0, accuracy: 1e-9)

        let infInitItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 80, y: 90),
            endPoint: CGPoint(x: 80, y: 90),
            strokeColor: .white,
            text: "Safe Inf",
            fontSize: .infinity
        )
        XCTAssertEqual(infInitItem.fontSize, 24.0, accuracy: 1e-6)

        var corruptedItem = nanInitItem
        corruptedItem.fontSize = .nan
        canvas.annotations = [corruptedItem]
        canvas.selectedIDs = [corruptedItem.id]
        settings.currentDrawMode = .text

        var reportedSizes: [Double] = []
        let controls = AnnotateControlsView(
            settings: settings,
            canvasState: canvas,
            onTextSizeChanged: { reportedSizes.append($0) }
        )
        XCTAssertEqual(controls.displayedTextFontSize, 24.0, accuracy: 1e-6)
        let hostingCorruptedItem = FirstMouseHostingView(rootView: controls)
        hostingCorruptedItem.frame = NSRect(x: 0, y: 0, width: 720, height: 52)
        hostingCorruptedItem.layoutSubtreeIfNeeded()

        controls.increaseTextSize()
        XCTAssertEqual(canvas.annotations[0].fontSize, 26.0, accuracy: 1e-6)
        XCTAssertEqual(settings.annotateFontSize, 26.0, accuracy: 1e-6)
        XCTAssertEqual(reportedSizes.last ?? 0, 26.0, accuracy: 1e-6)

        canvas.selectedIDs.removeAll()
        settings.annotateFontSize = .nan
        XCTAssertEqual(controls.displayedTextFontSize, 24.0, accuracy: 1e-6)
        let hostingCorruptedSetting = FirstMouseHostingView(rootView: controls)
        hostingCorruptedSetting.frame = NSRect(x: 0, y: 0, width: 720, height: 52)
        hostingCorruptedSetting.layoutSubtreeIfNeeded()

        controls.decreaseTextSize()
        XCTAssertEqual(settings.annotateFontSize, 22.0, accuracy: 1e-6)
        XCTAssertEqual(reportedSizes.last ?? 0, 22.0, accuracy: 1e-6)

        settings.annotateFontSize = .infinity
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(settings.annotateFontSize, 26.0, accuracy: 1e-6)

        let shortcuts = ShortcutManager(defaults: testDefaults)
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: canvas)
        overlay.showAnnotation()
        overlay.canvasView?.onTextSizeChanged?(.nan)
        XCTAssertEqual(overlay.toastController.currentMessage, "Text Size: 24 pt")
        overlay.canvasView?.onTextSizeChanged?(.infinity)
        XCTAssertEqual(overlay.toastController.currentMessage, "Text Size: 24 pt")
        overlay.hideAnnotation()

        let moveTarget = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 100, y: 120),
            endPoint: CGPoint(x: 100, y: 120),
            strokeColor: .white,
            text: "Move Guard",
            fontSize: 24.0
        )
        canvas.annotations = [moveTarget]
        canvas.selectedIDs = [moveTarget.id]
        let undoBeforeInvalidMove = canvas.undoStack.count
        canvas.moveSelectedAnnotations(by: CGSize(width: CGFloat.nan, height: 0))
        canvas.moveSelectedAnnotations(by: CGSize(width: 12, height: CGFloat.infinity))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeInvalidMove)
        XCTAssertEqual(canvas.annotations[0].startPoint, CGPoint(x: 100, y: 120))
        XCTAssertEqual(canvas.annotations[0].points, [CGPoint(x: 100, y: 120)])

        view.beginInlineTextEditing(at: CGPoint(x: CGFloat.nan, y: 80))
        XCTAssertNil(view.activeTextField)
        view.beginInlineTextEditing(at: CGPoint(x: 80, y: CGFloat.infinity))
        XCTAssertNil(view.activeTextField)

        let undoBeforeInvalidAdd = canvas.undoStack.count
        canvas.addOrUpdateTextAnnotation(at: CGPoint(x: CGFloat.nan, y: 40), text: "Rejected", color: .white)
        canvas.addOrUpdateTextAnnotation(
            id: moveTarget.id,
            at: CGPoint(x: 40, y: CGFloat.infinity),
            text: "Rejected Update",
            color: .white
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeInvalidAdd)
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertEqual(canvas.annotations[0].text, "Move Guard")

        canvas.setTextRotation(1_000.0 * Double.pi + (Double.pi / 3.0), for: moveTarget.id)
        XCTAssertEqual(canvas.annotations[0].rotationRadians, Double.pi / 3.0, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(abs(canvas.annotations[0].rotationRadians), Double.pi)

        for _ in 0..<60 {
            canvas.rotateSelectedTextAnnotations(by: 1.9)
        }
        canvas.rotateSelectedTextAnnotations(by: 1e100)
        XCTAssertTrue(canvas.annotations[0].rotationRadians.isFinite)
        XCTAssertLessThanOrEqual(abs(canvas.annotations[0].rotationRadians), Double.pi)
        guard let exportedAfterRotations = canvas.exportSessionData() else {
            XCTFail("Expected non-nil session export after repeated rotations")
            return
        }
        let roundTripCanvas = AnnotationCanvasState()
        XCTAssertTrue(roundTripCanvas.importSessionData(exportedAfterRotations))
        XCTAssertEqual(
            roundTripCanvas.annotations[0].rotationRadians,
            canvas.annotations[0].rotationRadians,
            accuracy: 1e-9
        )

        let oversizedString = String(repeating: "M", count: 5_000)
        let cappedItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 20, y: 30),
            endPoint: CGPoint(x: 20, y: 30),
            strokeColor: .white,
            text: oversizedString
        )
        XCTAssertEqual(cappedItem.text.count, 2_048)

        canvas.addOrUpdateTextAnnotation(at: CGPoint(x: 30, y: 40), text: oversizedString, color: .white)
        XCTAssertEqual(canvas.annotations.last?.text.count, 2_048)

        view.beginInlineTextEditing(at: CGPoint(x: 50, y: 60))
        guard let liveField = view.activeTextField else {
            XCTFail("Expected activeTextField for finite origin")
            return
        }
        liveField.stringValue = oversizedString
        view.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: liveField))
        XCTAssertEqual(liveField.stringValue.count, 2_048)
        liveField.stringValue = oversizedString
        view.commitActiveTextEditing()
        XCTAssertEqual(canvas.annotations.last?.text.count, 2_048)

        let baselineCachedRect = cappedItem.textLayoutRect
        for idx in 0..<280 {
            let transient = AnnotationItem(
                mode: .text,
                startPoint: CGPoint(x: 10, y: 10),
                endPoint: CGPoint(x: 10, y: 10),
                strokeColor: .white,
                text: "Cache Entry \(idx)",
                fontSize: 20.0
            )
            XCTAssertGreaterThanOrEqual(transient.textLayoutRect.width, 24.0)
        }
        XCTAssertEqual(cappedItem.textLayoutRect, baselineCachedRect)

        let seed = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 25, y: 35),
            endPoint: CGPoint(x: 25, y: 35),
            strokeColor: .white,
            text: "Preserved Seed",
            fontSize: 24.0
        )
        canvas.annotations = [seed]

        let over4MBData = Data(repeating: 0x20, count: 4_194_305)
        XCTAssertFalse(canvas.importSessionData(over4MBData))
        XCTAssertEqual(canvas.annotations, [seed])

        let over2000Items = Array(repeating: seed, count: 2_001)
        let over2000Data = try JSONEncoder().encode(over2000Items)
        XCTAssertLessThanOrEqual(over2000Data.count, 4_194_304)
        XCTAssertFalse(canvas.importSessionData(over2000Data))
        XCTAssertEqual(canvas.annotations, [seed])

        let over10kPointsItem = AnnotationItem(
            mode: .freeHand,
            points: Array(repeating: CGPoint(x: 15, y: 15), count: 10_001),
            startPoint: CGPoint(x: 15, y: 15),
            endPoint: CGPoint(x: 15, y: 15),
            strokeColor: .red
        )
        let over10kPointsData = try JSONEncoder().encode([over10kPointsItem])
        XCTAssertLessThanOrEqual(over10kPointsData.count, 4_194_304)
        XCTAssertFalse(canvas.importSessionData(over10kPointsData))
        XCTAssertEqual(canvas.annotations, [seed])

        let over2048TextString = String(repeating: "Z", count: 2_049)
        let over2048TextJSON = """
        [
          {
            "id": "7621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "mode": "text",
            "points": [[20, 20]],
            "startPoint": [20, 20],
            "endPoint": [20, 20],
            "isConstrained": false,
            "isFilled": false,
            "strokeColor": {"red": 1, "green": 1, "blue": 1, "alpha": 1},
            "lineWeight": 2,
            "isHighlighter": false,
            "isAutoErase": false,
            "createdAt": 100,
            "text": "\(over2048TextString)",
            "fontName": ".AppleSystemUIFont",
            "fontSize": 24
          }
        ]
        """.data(using: .utf8)!
        XCTAssertFalse(canvas.importSessionData(over2048TextJSON))
        XCTAssertEqual(canvas.annotations, [seed])
    }

    func testInterruptedTransformResetsOnHideAnnotationAndInteractivePassThroughRelease() {
        let settings = AppSettings(defaults: testDefaults)
        settings.annotateSaveSession = true
        settings.currentDrawMode = .text
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: canvas)

        let textItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 120, y: 140),
            endPoint: CGPoint(x: 120, y: 140),
            strokeColor: .white,
            text: "Interrupt Target",
            fontSize: 24.0
        )
        canvas.annotations = [textItem]
        canvas.selectedIDs = [textItem.id]

        overlay.showAnnotation()
        guard let panel = overlay.panel, let view = overlay.canvasView else {
            XCTFail("Expected overlay panel and canvasView")
            return
        }

        let startPt = canvas.annotations[0].textCenter
        let dragMidPt = CGPoint(x: startPt.x + 25, y: startPt.y + 15)
        let undoBeforeHideInterrupt = canvas.undoStack.count

        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: startPt), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: dragMidPt), in: panel))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeHideInterrupt + 1)

        overlay.hideAnnotation()
        overlay.showAnnotation()
        canvas.selectedIDs = [textItem.id]

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].fontSize, 26.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeHideInterrupt + 2)

        settings.annotateInteractiveMode = true
        settings.interactiveModeKey = .fn
        overlay.updateInteractivePassThrough(modifierFlags: [.function])
        XCTAssertFalse(panel.ignoresMouseEvents)

        let scaleHandle = canvas.annotations[0].worldTextScaleHandleCenters[2]
        let scaleCenter = canvas.annotations[0].textCenter
        let scaleDragPt = CGPoint(
            x: scaleCenter.x + (scaleHandle.x - scaleCenter.x) * 1.4,
            y: scaleCenter.y + (scaleHandle.y - scaleCenter.y) * 1.4
        )
        let undoBeforeFnRelease = canvas.undoStack.count

        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: scaleHandle), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: scaleDragPt), in: panel))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeFnRelease + 1)

        overlay.updateInteractivePassThrough(modifierFlags: [])
        XCTAssertTrue(panel.ignoresMouseEvents)

        overlay.updateInteractivePassThrough(modifierFlags: [.function])
        XCTAssertFalse(panel.ignoresMouseEvents)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeFnRelease + 2)

        let nextDragStart = canvas.annotations[0].textCenter
        let nextDragEnd = CGPoint(x: nextDragStart.x + 18, y: nextDragStart.y - 12)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: nextDragStart), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: nextDragEnd), in: panel))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: nextDragEnd), in: panel))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeFnRelease + 3)

        settings.annotateSaveSession = false
        overlay.hideAnnotation()
    }

    func testMultiSelectedRotatedTextRendersDashedSelectionFrameWhileSuppressingSingleItemHandles() {
        let harness = makeCanvasHarness()
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        settings.isWhiteboardActive = false
        settings.dimScreenOnAnnotate = false
        settings.annotateToolIndicator = false

        let rotatedText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 150, y: 150),
            endPoint: CGPoint(x: 150, y: 150),
            strokeColor: .yellow,
            text: "Multi Select Frame",
            fontSize: 32.0,
            rotationRadians: Double.pi / 6.0
        )
        let otherRect = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 60, y: 60),
            strokeColor: .green
        )
        canvas.annotations = [rotatedText, otherRect]
        canvas.selectedIDs = [rotatedText.id, otherRect.id]

        guard let pngData = Screenshotter.renderViewToPNGData(view),
              let cgImage = NSBitmapImageRep(data: pngData)?.cgImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            XCTFail("Expected rendered PNG for multi-selected rotated text")
            return
        }

        let imgWidth = cgImage.width
        let imgHeight = cgImage.height
        var bytes = [UInt8](repeating: 0, count: imgWidth * imgHeight * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let didRasterize = bytes.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: imgWidth,
                height: imgHeight,
                bitsPerComponent: 8,
                bytesPerRow: imgWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
            return true
        }
        XCTAssertTrue(didRasterize)

        let scaleX = Double(imgWidth) / Double(max(1.0, view.bounds.width))
        let scaleY = Double(imgHeight) / Double(max(1.0, view.bounds.height))
        let localBox = rotatedText.textSelectionBox
        var foundDashedLightBlueBorder = false
        for step in 2...18 {
            let fraction = CGFloat(step) / 20.0
            let localEdgePoint = CGPoint(
                x: localBox.minX + localBox.width * fraction,
                y: localBox.maxY
            )
            let worldEdgePoint = rotatedText.fromTextLocalSpace(localEdgePoint)
            let edgePxX = Int((Double(worldEdgePoint.x) * scaleX).rounded())
            let edgePxY = Int((Double(view.bounds.height - worldEdgePoint.y) * scaleY).rounded())
            for dy in -2...2 {
                for dx in -2...2 {
                    let pxX = edgePxX + dx
                    let pxY = edgePxY + dy
                    let inX = pxX >= 0 && pxX < imgWidth
                    let inY = pxY >= 0 && pxY < imgHeight
                    guard inX && inY else { continue }
                    let offset = (pxY * imgWidth + pxX) * 4
                    let r = bytes[offset]
                    let b = bytes[offset + 2]
                    let a = bytes[offset + 3]
                    let isBlueOverRed = Int(b) > Int(r) + 60
                    let isVisibleStroke = a >= 80 && b >= 120
                    if isBlueOverRed && isVisibleStroke {
                        foundDashedLightBlueBorder = true
                    }
                }
            }
        }
        XCTAssertTrue(foundDashedLightBlueBorder)

        let rotHandle = rotatedText.worldTextRotationHandleCenter
        let rotPxX = Int((Double(rotHandle.x) * scaleX).rounded())
        let rotPxY = Int((Double(view.bounds.height - rotHandle.y) * scaleY).rounded())
        var maxRotationHandleAlpha: UInt8 = 0
        for dy in -4...4 {
            for dx in -4...4 {
                let pxX = rotPxX + dx
                let pxY = rotPxY + dy
                let inX = pxX >= 0 && pxX < imgWidth
                let inY = pxY >= 0 && pxY < imgHeight
                guard inX && inY else { continue }
                let offset = (pxY * imgWidth + pxX) * 4
                let a = bytes[offset + 3]
                if a > maxRotationHandleAlpha {
                    maxRotationHandleAlpha = a
                }
            }
        }
        XCTAssertEqual(maxRotationHandleAlpha, 0)

        var foundAnyCornerWhiteFill = false
        for corner in rotatedText.worldTextScaleHandleCenters {
            let cornerPxX = Int((Double(corner.x) * scaleX).rounded())
            let cornerPxY = Int((Double(view.bounds.height - corner.y) * scaleY).rounded())
            let inX = cornerPxX >= 0 && cornerPxX < imgWidth
            let inY = cornerPxY >= 0 && cornerPxY < imgHeight
            guard inX && inY else { continue }
            let offset = (cornerPxY * imgWidth + cornerPxX) * 4
            let r = bytes[offset]
            let g = bytes[offset + 1]
            let b = bytes[offset + 2]
            let a = bytes[offset + 3]
            let isWhiteRG = r >= 235 && g >= 235
            let isOpaqueWhite = b >= 235 && a >= 245
            if isWhiteRG && isOpaqueWhite {
                foundAnyCornerWhiteFill = true
            }
        }
        XCTAssertFalse(foundAnyCornerWhiteFill)
    }

    func testOrphanedDragScaleAndRotateRecoverOnResignKeyAndNextMouseDownWithoutMouseUp() {
        let settings = AppSettings(defaults: testDefaults)
        settings.annotateSaveSession = false
        settings.currentDrawMode = .text
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: canvas)

        let textItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 140, y: 150),
            endPoint: CGPoint(x: 140, y: 150),
            strokeColor: .white,
            text: "Orphan Recovery",
            fontSize: 24.0
        )
        canvas.annotations = [textItem]
        canvas.selectedIDs = [textItem.id]

        overlay.showAnnotation()
        guard let panel = overlay.panel, let view = overlay.canvasView else {
            XCTFail("Expected overlay panel and canvasView")
            return
        }
        XCTAssertTrue(panel.isVisible)
        XCTAssertTrue(settings.isAnnotating)

        let moveStart = canvas.annotations[0].textCenter
        let moveMid = CGPoint(x: moveStart.x + 24, y: moveStart.y + 14)
        let undoBeforeMoveResign = canvas.undoStack.count
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: moveStart), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: moveMid), in: panel))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeMoveResign + 1)

        panel.resignKey()
        XCTAssertTrue(panel.isVisible)
        XCTAssertTrue(settings.isAnnotating)
        XCTAssertEqual(canvas.selectedIDs, [textItem.id])

        canvas.moveSelectedAnnotations(by: CGSize(width: 10, height: -6))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeMoveResign + 2)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].fontSize, 26.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeMoveResign + 3)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].fontSize, 24.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeMoveResign + 4)

        let scaleHandle = canvas.annotations[0].worldTextScaleHandleCenters[2]
        let scaleCenter = canvas.annotations[0].textCenter
        let scaleDragPt = CGPoint(
            x: scaleCenter.x + (scaleHandle.x - scaleCenter.x) * 1.35,
            y: scaleCenter.y + (scaleHandle.y - scaleCenter.y) * 1.35
        )
        let undoBeforeScaleResign = canvas.undoStack.count
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: scaleHandle), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: scaleDragPt), in: panel))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeScaleResign + 1)

        panel.resignKey()
        XCTAssertTrue(panel.isVisible)
        canvas.moveSelectedAnnotations(by: CGSize(width: -8, height: 4))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeScaleResign + 2)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeScaleResign + 3)

        let rotHandle = canvas.annotations[0].worldTextRotationHandleCenter
        let rotCenter = canvas.annotations[0].textCenter
        let rotDragPt = CGPoint(x: rotCenter.x + 48, y: rotCenter.y)
        let undoBeforeRotateResign = canvas.undoStack.count
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: rotHandle), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: rotDragPt), in: panel))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeRotateResign + 1)

        panel.resignKey()
        XCTAssertTrue(panel.isVisible)
        canvas.moveSelectedAnnotations(by: CGSize(width: 6, height: 6))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeRotateResign + 2)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeRotateResign + 3)

        settings.currentDrawMode = .freeHand
        canvas.selectedIDs = [textItem.id]
        let orphanMoveStart = canvas.annotations[0].textCenter
        let orphanMoveMid = CGPoint(x: orphanMoveStart.x + 15, y: orphanMoveStart.y + 10)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: orphanMoveStart), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: orphanMoveMid), in: panel))
        let frozenAfterMove = canvas.annotations[0]
        let undoAfterInterruptedMove = canvas.undoStack.count

        let strokeAStart = CGPoint(x: 24, y: 28)
        let strokeAMid = CGPoint(x: 64, y: 52)
        let strokeAEnd = CGPoint(x: 96, y: 74)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: strokeAStart), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: strokeAMid), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: strokeAEnd), in: panel))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: strokeAEnd), in: panel))

        XCTAssertEqual(canvas.annotations[0].startPoint, frozenAfterMove.startPoint)
        XCTAssertEqual(canvas.annotations[0].fontSize, frozenAfterMove.fontSize, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].rotationRadians, frozenAfterMove.rotationRadians, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations.count, 2)
        XCTAssertEqual(canvas.annotations[1].mode, .freeHand)
        XCTAssertNil(canvas.activeDraft)
        XCTAssertEqual(canvas.undoStack.count, undoAfterInterruptedMove + 1)

        canvas.selectedIDs = [textItem.id]
        let orphanCorner = canvas.annotations[0].worldTextScaleHandleCenters[0]
        let centerBeforeOrphanScale = canvas.annotations[0].textCenter
        let orphanCornerOut = CGPoint(
            x: centerBeforeOrphanScale.x + (orphanCorner.x - centerBeforeOrphanScale.x) * 1.25,
            y: centerBeforeOrphanScale.y + (orphanCorner.y - centerBeforeOrphanScale.y) * 1.25
        )
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: orphanCorner), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: orphanCornerOut), in: panel))
        let frozenAfterScale = canvas.annotations[0]
        let countAfterScale = canvas.annotations.count
        let undoAfterInterruptedScale = canvas.undoStack.count

        let strokeBStart = CGPoint(x: 20, y: 300)
        let strokeBMid = CGPoint(x: 70, y: 320)
        let strokeBEnd = CGPoint(x: 105, y: 330)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: strokeBStart), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: strokeBMid), in: panel))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: strokeBEnd), in: panel))

        XCTAssertEqual(canvas.annotations[0].startPoint, frozenAfterScale.startPoint)
        XCTAssertEqual(canvas.annotations[0].fontSize, frozenAfterScale.fontSize, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].rotationRadians, frozenAfterScale.rotationRadians, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations.count, countAfterScale + 1)
        XCTAssertEqual(canvas.annotations.last?.mode, .freeHand)
        XCTAssertNil(canvas.activeDraft)
        XCTAssertEqual(canvas.undoStack.count, undoAfterInterruptedScale + 1)

        canvas.selectedIDs = [textItem.id]
        let orphanRot = canvas.annotations[0].worldTextRotationHandleCenter
        let centerBeforeOrphanRot = canvas.annotations[0].textCenter
        let orphanRotOut = CGPoint(x: centerBeforeOrphanRot.x - 45, y: centerBeforeOrphanRot.y + 20)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: orphanRot), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: orphanRotOut), in: panel))
        let frozenAfterRotate = canvas.annotations[0]
        let countAfterRotate = canvas.annotations.count
        let undoAfterInterruptedRotate = canvas.undoStack.count

        let strokeCStart = CGPoint(x: 300, y: 25)
        let strokeCMid = CGPoint(x: 345, y: 45)
        let strokeCEnd = CGPoint(x: 380, y: 60)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: strokeCStart), in: panel))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: strokeCMid), in: panel))
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: strokeCEnd), in: panel))

        XCTAssertEqual(canvas.annotations[0].startPoint, frozenAfterRotate.startPoint)
        XCTAssertEqual(canvas.annotations[0].fontSize, frozenAfterRotate.fontSize, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].rotationRadians, frozenAfterRotate.rotationRadians, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations.count, countAfterRotate + 1)
        XCTAssertEqual(canvas.annotations.last?.mode, .freeHand)
        XCTAssertNil(canvas.activeDraft)
        XCTAssertEqual(canvas.undoStack.count, undoAfterInterruptedRotate + 1)

        canvas.selectedIDs = [textItem.id]
        let rightClickStart = canvas.annotations[0].textCenter
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: rightClickStart), in: panel))
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: rightClickStart.x + 8, y: rightClickStart.y + 8)),
                in: panel
            )
        )
        let undoAfterRightClickDrag = canvas.undoStack.count
        view.rightMouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .rightMouseDown, location: rightClickStart), in: panel))
        canvas.moveSelectedAnnotations(by: CGSize(width: 4, height: 4))
        XCTAssertEqual(canvas.undoStack.count, undoAfterRightClickDrag + 1)

        let hoverCleanupStart = canvas.annotations[0].textCenter
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: hoverCleanupStart), in: panel))
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: hoverCleanupStart.x + 6, y: hoverCleanupStart.y - 6)),
                in: panel
            )
        )
        let undoAfterHoverDrag = canvas.undoStack.count
        view.mouseMoved(with: makeMouseEvent(SyntheticMouseSpec(type: .mouseMoved, location: CGPoint(x: 15, y: 15)), in: panel))
        canvas.moveSelectedAnnotations(by: CGSize(width: 4, height: 4))
        XCTAssertEqual(canvas.undoStack.count, undoAfterHoverDrag + 1)

        let deactivateStart = canvas.annotations[0].textCenter
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: deactivateStart), in: panel))
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: deactivateStart.x - 6, y: deactivateStart.y + 6)),
                in: panel
            )
        )
        let undoAfterDeactivateDrag = canvas.undoStack.count
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        canvas.moveSelectedAnnotations(by: CGSize(width: 4, height: 4))
        XCTAssertEqual(canvas.undoStack.count, undoAfterDeactivateDrag + 1)

        overlay.hideAnnotation()
    }

    private struct StrokeDragSpec {
        var start: CGPoint
        var end: CGPoint
        var midpoints: [CGPoint] = []
        var modifiers: NSEvent.ModifierFlags = []
    }

    private func performMouseDrag(_ spec: StrokeDragSpec, on target: (window: NSWindow, view: AnnotateCanvasView)) {
        target.view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: spec.start, modifiers: spec.modifiers),
                in: target.window
            )
        )
        for midpoint in spec.midpoints {
            target.view.mouseDragged(
                with: makeMouseEvent(
                    SyntheticMouseSpec(type: .leftMouseDragged, location: midpoint, modifiers: spec.modifiers),
                    in: target.window
                )
            )
        }
        target.view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: spec.end, modifiers: spec.modifiers),
                in: target.window
            )
        )
        target.view.mouseUp(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseUp, location: spec.end, modifiers: spec.modifiers),
                in: target.window
            )
        )
    }

    private struct RasterizedCanvas {
        var width: Int
        var height: Int
        var scaleX: Double
        var scaleY: Double
        var viewHeight: CGFloat
        var bytes: [UInt8]

        func pixelRGBA(at viewPoint: CGPoint) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
            let hasFinitePoint = viewPoint.x.isFinite && viewPoint.y.isFinite
            let hasFiniteScale = scaleX.isFinite && scaleY.isFinite
            guard hasFinitePoint && hasFiniteScale else { return nil }
            let rawX = Double(viewPoint.x) * scaleX
            let rawY = Double(viewHeight - viewPoint.y) * scaleY
            guard rawX.isFinite && rawY.isFinite else { return nil }
            let pxX = Int(rawX.rounded())
            let pxY = Int(rawY.rounded())
            let inX = pxX >= 0 && pxX < width
            let inY = pxY >= 0 && pxY < height
            guard inX && inY else { return nil }
            let offset = (pxY * width + pxX) * 4
            return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
        }
    }

    private func rasterizeCanvasView(_ view: AnnotateCanvasView) -> RasterizedCanvas? {
        guard let pngData = Screenshotter.renderViewToPNGData(view),
              let cgImage = NSBitmapImageRep(data: pngData)?.cgImage else {
            return nil
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        let imgWidth = cgImage.width
        let imgHeight = cgImage.height
        var bytes = [UInt8](repeating: 0, count: imgWidth * imgHeight * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let didRasterize = bytes.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: imgWidth,
                height: imgHeight,
                bitsPerComponent: 8,
                bytesPerRow: imgWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
            return true
        }
        guard didRasterize else { return nil }
        let scaleX = Double(imgWidth) / Double(max(1.0, view.bounds.width))
        let scaleY = Double(imgHeight) / Double(max(1.0, view.bounds.height))
        return RasterizedCanvas(
            width: imgWidth,
            height: imgHeight,
            scaleX: scaleX,
            scaleY: scaleY,
            viewHeight: view.bounds.height,
            bytes: bytes
        )
    }

    private func sendColorPanelColor(_ color: PresentifyCore.RGBColor) {
        _ = NSApplication.shared
        let panel = NSColorPanel.shared
        panel.color = color.nsColor
        CustomColorPanelBridge.shared.colorPanelDidChange(panel)
    }

    func testPostDrawAutoSelectionAllowsImmediateRecolorAndCornerScaleWithoutBreakingConsecutiveStrokes() {
        let headless = AnnotationCanvasState()
        headless.beginStroke(at: CGPoint(x: 10, y: 10), mode: .arrow, color: .red, lineWeight: 4.0)
        headless.updateStroke(to: CGPoint(x: 60, y: 40))
        let headlessArrowID = headless.finishStroke()
        XCTAssertNotNil(headlessArrowID)
        XCTAssertTrue(headless.selectedIDs.isEmpty)

        headless.beginStroke(at: CGPoint(x: 10, y: 10), mode: .blur, color: .red, lineWeight: 4.0)
        headless.updateStroke(to: CGPoint(x: 10.5, y: 10.5))
        XCTAssertNil(headless.finishStroke())

        let headlessTextID = headless.addOrUpdateTextAnnotation(
            at: CGPoint(x: 20, y: 20),
            text: "Headless",
            color: .white
        )
        XCTAssertNotNil(headlessTextID)
        XCTAssertTrue(headless.selectedIDs.isEmpty)
        XCTAssertNil(
            headless.addOrUpdateTextAnnotation(
                id: headlessTextID,
                at: CGPoint(x: 20, y: 20),
                text: "   ",
                color: .white
            )
        )

        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)
        let target = (window: window, view: view)

        settings.selectFavoriteColor(index: 0)
        settings.currentDrawMode = .arrow
        performMouseDrag(
            StrokeDragSpec(start: CGPoint(x: 40, y: 60), end: CGPoint(x: 140, y: 120)),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 1)
        let arrowID = canvas.annotations[0].id
        XCTAssertEqual(canvas.selectedIDs, [arrowID])
        XCTAssertTrue(view.isPostDrawAutoSelection)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x13, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].strokeColor, settings.favColors[1])

        let arrowTopRight = canvas.annotations[0].selectionScaleHandleCenters[2]
        performMouseDrag(
            StrokeDragSpec(
                start: arrowTopRight,
                end: CGPoint(x: arrowTopRight.x + 30, y: arrowTopRight.y + 20)
            ),
            on: target
        )
        XCTAssertFalse(view.isPostDrawAutoSelection)
        XCTAssertEqual(canvas.annotations[0].startPoint, CGPoint(x: 40, y: 60))
        XCTAssertEqual(canvas.annotations[0].endPoint.x, 170, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint.y, 140, accuracy: 1e-6)

        settings.currentDrawMode = .freeHand
        performMouseDrag(
            StrokeDragSpec(
                start: CGPoint(x: 200, y: 60),
                end: CGPoint(x: 200, y: 160),
                midpoints: [CGPoint(x: 200, y: 110)]
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 2)
        let stemSnapshot = canvas.annotations[1]
        XCTAssertEqual(canvas.selectedIDs, [stemSnapshot.id])
        XCTAssertTrue(view.isPostDrawAutoSelection)

        performMouseDrag(
            StrokeDragSpec(
                start: CGPoint(x: 200, y: 110),
                end: CGPoint(x: 245, y: 110),
                midpoints: [CGPoint(x: 222, y: 110)]
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 3)
        XCTAssertEqual(canvas.annotations[1], stemSnapshot)
        XCTAssertEqual(canvas.selectedIDs, [canvas.annotations[2].id])
        XCTAssertTrue(view.isPostDrawAutoSelection)

        settings.currentDrawMode = .rectangle
        performMouseDrag(
            StrokeDragSpec(start: CGPoint(x: 260, y: 50), end: CGPoint(x: 320, y: 100)),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 4)
        let rectID = canvas.annotations[3].id
        XCTAssertEqual(canvas.selectedIDs, [rectID])
        XCTAssertTrue(view.isPostDrawAutoSelection)

        settings.currentDrawMode = .blur
        performMouseDrag(
            StrokeDragSpec(start: CGPoint(x: 260, y: 130), end: CGPoint(x: 335, y: 190)),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 5)
        let blurID = canvas.annotations[4].id
        XCTAssertEqual(canvas.selectedIDs, [blurID])
        XCTAssertTrue(view.isPostDrawAutoSelection)
        controls.selectFavoriteColor(at: 2)
        XCTAssertEqual(canvas.annotations[4].blurTintColor, settings.favColors[2])

        settings.currentDrawMode = .text
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: CGPoint(x: 80, y: 240)), in: window))
        view.activeTextField?.stringValue = "Auto Selected Text"
        view.commitActiveTextEditing()
        XCTAssertEqual(canvas.annotations.count, 6)
        let textID = canvas.annotations[5].id
        XCTAssertEqual(canvas.selectedIDs, [textID])
        XCTAssertTrue(view.isPostDrawAutoSelection)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x15, modifiers: 0))
        XCTAssertEqual(canvas.annotations[5].strokeColor, settings.favColors[3])

        settings.currentDrawMode = .rectangle
        let rectEdgePoint = CGPoint(x: 260, y: 75)
        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: rectEdgePoint, modifiers: [.command]),
                in: window
            )
        )
        view.mouseUp(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseUp, location: rectEdgePoint, modifiers: [.command]),
                in: window
            )
        )
        XCTAssertEqual(canvas.selectedIDs, [rectID])
        XCTAssertFalse(view.isPostDrawAutoSelection)

        performMouseDrag(
            StrokeDragSpec(start: rectEdgePoint, end: CGPoint(x: 280, y: 90)),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 6)
        XCTAssertEqual(canvas.annotations[3].startPoint, CGPoint(x: 280, y: 65))
        XCTAssertEqual(canvas.annotations[3].endPoint, CGPoint(x: 340, y: 115))
    }

    func testDirectAndLiveColorPanelRecoloringAcrossAllModesCoalescesUndo() {
        let settings = AppSettings(defaults: testDefaults)
        settings.annotateSaveSession = false
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: canvas)
        overlay.showAnnotation()
        defer {
            CustomColorPanelBridge.shared.close()
            overlay.hideAnnotation()
        }
        guard let view = overlay.canvasView else {
            XCTFail("Expected overlay canvasView")
            return
        }
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)

        let textItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 40, y: 40),
            endPoint: CGPoint(x: 40, y: 40),
            strokeColor: .white,
            text: "Recolor",
            fontSize: 24.0
        )
        let arrowItem = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 40, y: 90), CGPoint(x: 120, y: 130)],
            startPoint: CGPoint(x: 40, y: 90),
            endPoint: CGPoint(x: 120, y: 130),
            strokeColor: .red,
            lineWeight: 4.0
        )
        let freeHandItem = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 40, y: 150), CGPoint(x: 90, y: 170), CGPoint(x: 130, y: 155)],
            startPoint: CGPoint(x: 40, y: 150),
            endPoint: CGPoint(x: 130, y: 155),
            strokeColor: .red,
            lineWeight: 5.0
        )
        let rectItem = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 160, y: 40),
            endPoint: CGPoint(x: 230, y: 95),
            strokeColor: .red,
            lineWeight: 4.0
        )
        let circleItem = AnnotationItem(
            mode: .circle,
            startPoint: CGPoint(x: 160, y: 120),
            endPoint: CGPoint(x: 230, y: 180),
            strokeColor: .red,
            lineWeight: 4.0
        )
        let highlighterItem = AnnotationItem(
            mode: .highlighter,
            points: [CGPoint(x: 40, y: 210), CGPoint(x: 150, y: 210)],
            startPoint: CGPoint(x: 40, y: 210),
            endPoint: CGPoint(x: 150, y: 210),
            strokeColor: PresentifyCore.RGBColor.red.withAlpha(0.42),
            lineWeight: 18.0,
            isHighlighter: true
        )
        let blurItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 260, y: 60),
            endPoint: CGPoint(x: 340, y: 130),
            strokeColor: .red,
            blurStyle: .gaussian,
            blurOpacity: 0.6,
            blurTintColor: .white
        )

        canvas.annotations = [textItem, arrowItem, freeHandItem, rectItem, circleItem, highlighterItem, blurItem]
        canvas.selectedIDs = Set(canvas.annotations.map(\.id))

        controls.selectFavoriteColor(at: 2)
        let favTwo = settings.favColors[2]
        XCTAssertEqual(canvas.annotations[0].strokeColor, favTwo)
        XCTAssertNil(canvas.annotations[0].gradientPair)
        XCTAssertEqual(canvas.annotations[1].strokeColor, favTwo)
        XCTAssertEqual(canvas.annotations[2].strokeColor, favTwo)
        XCTAssertEqual(canvas.annotations[3].strokeColor, favTwo)
        XCTAssertEqual(canvas.annotations[4].strokeColor, favTwo)
        XCTAssertEqual(canvas.annotations[5].strokeColor, favTwo.withAlpha(0.42))
        XCTAssertEqual(canvas.annotations[5].strokeColor.alpha, 0.42, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[6].blurTintColor, favTwo)
        XCTAssertTrue(settings.blurUseCustomColor)
        XCTAssertEqual(settings.blurCustomColor, favTwo)

        controls.selectRandomColors()
        let activeGrad = settings.activeGradient
        let resolvedRandomColor = settings.blurCustomColor
        XCTAssertEqual(canvas.annotations[0].strokeColor, resolvedRandomColor)
        XCTAssertEqual(canvas.annotations[1].strokeColor, resolvedRandomColor)
        XCTAssertNil(canvas.annotations[0].gradientPair)
        XCTAssertEqual(canvas.annotations[1].gradientPair, activeGrad)
        XCTAssertEqual(canvas.annotations[2].gradientPair, activeGrad)
        XCTAssertEqual(canvas.annotations[3].gradientPair, activeGrad)
        XCTAssertEqual(canvas.annotations[4].gradientPair, activeGrad)
        XCTAssertEqual(canvas.annotations[5].gradientPair, activeGrad)
        XCTAssertEqual(canvas.annotations[5].strokeColor.alpha, 0.42, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[6].blurTintColor, resolvedRandomColor)

        let shortcutKeyCodes: [(UInt16, Int)] = [(0x12, 0), (0x13, 1), (0x14, 2), (0x15, 3), (0x17, 4)]
        for (keyCode, favIndex) in shortcutKeyCodes {
            XCTAssertTrue(view.handleKeyCommand(keyCode: keyCode, modifiers: 0))
            let expected = settings.favColors[favIndex]
            XCTAssertEqual(canvas.annotations[1].strokeColor, expected)
            XCTAssertNil(canvas.annotations[1].gradientPair)
            XCTAssertEqual(canvas.annotations[5].strokeColor.alpha, 0.42, accuracy: 1e-6)
            XCTAssertEqual(canvas.annotations[6].blurTintColor, expected)
        }
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x16, modifiers: 0))
        XCTAssertNotNil(canvas.annotations[1].gradientPair)
        XCTAssertNil(canvas.annotations[0].gradientPair)

        canvas.selectedIDs = [textItem.id, arrowItem.id, highlighterItem.id]
        controls.selectFavoriteColor(at: 0)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        let baselineStrokeColor = canvas.annotations[1].strokeColor
        let undoBeforeStrokePanel = canvas.undoStack.count

        CustomColorPanelBridge.shared.present(for: settings, canvasState: canvas)
        let panelColors = [
            PresentifyCore.RGBColor(red: 0.92, green: 0.35, blue: 0.18),
            PresentifyCore.RGBColor(red: 0.22, green: 0.74, blue: 0.80),
            PresentifyCore.RGBColor(red: 0.16, green: 0.42, blue: 0.94),
            PresentifyCore.RGBColor(red: 0.12, green: 0.78, blue: 0.44)
        ]
        for color in panelColors {
            sendColorPanelColor(color)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        XCTAssertEqual(canvas.undoStack.count, undoBeforeStrokePanel + 1)
        XCTAssertEqual(canvas.annotations[0].strokeColor.red, 0.12, accuracy: 0.03)
        XCTAssertEqual(canvas.annotations[0].strokeColor.green, 0.78, accuracy: 0.03)
        XCTAssertEqual(canvas.annotations[1].strokeColor.blue, 0.44, accuracy: 0.03)
        XCTAssertEqual(canvas.annotations[5].strokeColor.alpha, 0.42, accuracy: 1e-6)

        canvas.undo()
        XCTAssertEqual(canvas.annotations[1].strokeColor, baselineStrokeColor)

        canvas.selectedIDs = [blurItem.id]
        canvas.applyColorUpdate(AnnotationColorUpdate(color: .white))
        settings.setCustomBlurTintColor(.white)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        let undoBeforeBlurPanel = canvas.undoStack.count

        CustomColorPanelBridge.shared.presentForBlurTint(for: settings, canvasState: canvas)
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.85, green: 0.25, blue: 0.25))
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.25, green: 0.65, blue: 0.85))
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.20, green: 0.82, blue: 0.52))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        XCTAssertEqual(canvas.undoStack.count, undoBeforeBlurPanel + 1)
        XCTAssertEqual(canvas.annotations[6].blurTintColor?.green ?? 0.0, 0.82, accuracy: 0.03)
        canvas.undo()
        XCTAssertEqual(canvas.annotations[6].blurTintColor, .white)
    }

    func testNonTextCornerScaleHandlesRenderSingleVsMultiSelectAndScaleAllModesWithUndo() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        settings.isWhiteboardActive = false
        settings.dimScreenOnAnnotate = false
        settings.annotateToolIndicator = false
        let target = (window: window, view: view)

        let rectItem = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 100, y: 100),
            endPoint: CGPoint(x: 220, y: 180),
            strokeColor: .yellow,
            lineWeight: 2.0
        )
        canvas.annotations = [rectItem]
        canvas.selectedIDs = [rectItem.id]

        guard let singleRaster = rasterizeCanvasView(view) else {
            XCTFail("Expected rasterized canvas for single-selected rectangle")
            return
        }
        for handleCenter in rectItem.selectionScaleHandleCenters {
            guard let centerRGBA = singleRaster.pixelRGBA(at: handleCenter) else {
                XCTFail("Expected handle center pixel in bounds")
                return
            }
            let isBrightR = centerRGBA.r >= 220 && centerRGBA.g >= 220
            let isBrightBA = centerRGBA.b >= 220 && centerRGBA.a >= 200
            XCTAssertTrue(isBrightR && isBrightBA)

            var foundBlueRing = false
            for dy in -6...6 {
                for dx in -6...6 {
                    let probe = CGPoint(x: handleCenter.x + CGFloat(dx), y: handleCenter.y + CGFloat(dy))
                    guard let ringRGBA = singleRaster.pixelRGBA(at: probe) else { continue }
                    let isStrongBlue = ringRGBA.b >= 170 && Int(ringRGBA.b) > Int(ringRGBA.r) + 70
                    if isStrongBlue && ringRGBA.a >= 120 {
                        foundBlueRing = true
                    }
                }
            }
            XCTAssertTrue(foundBlueRing)
        }

        for py in 85...195 {
            for px in 85...235 {
                guard let sample = singleRaster.pixelRGBA(at: CGPoint(x: px, y: py)) else { continue }
                let hasHighRB = sample.r >= 110 && sample.b >= 140
                let dominatesGreen = Int(sample.r) > Int(sample.g) + 45 && Int(sample.b) > Int(sample.g) + 45
                XCTAssertFalse(hasHighRB && dominatesGreen)
            }
        }

        let highlighterVisual = AnnotationItem(
            mode: .highlighter,
            points: [CGPoint(x: 90, y: 260), CGPoint(x: 210, y: 260)],
            startPoint: CGPoint(x: 90, y: 260),
            endPoint: CGPoint(x: 210, y: 260),
            strokeColor: PresentifyCore.RGBColor.yellow.withAlpha(0.42),
            lineWeight: 18.0,
            isHighlighter: true
        )
        canvas.annotations = [highlighterVisual]
        canvas.selectedIDs = [highlighterVisual.id]
        guard let highlighterRaster = rasterizeCanvasView(view),
              let hlCornerRGBA = highlighterRaster.pixelRGBA(at: highlighterVisual.selectionScaleHandleCenters[0]) else {
            XCTFail("Expected rasterized highlighter handle center")
            return
        }
        let hlWhiteRG = hlCornerRGBA.r >= 220 && hlCornerRGBA.g >= 220
        let hlWhiteBA = hlCornerRGBA.b >= 220 && hlCornerRGBA.a >= 200
        XCTAssertTrue(hlWhiteRG && hlWhiteBA)

        let secondCircle = AnnotationItem(
            mode: .circle,
            startPoint: CGPoint(x: 260, y: 100),
            endPoint: CGPoint(x: 330, y: 170),
            strokeColor: .green,
            lineWeight: 3.0
        )
        canvas.annotations = [rectItem, secondCircle]
        canvas.selectedIDs = [rectItem.id, secondCircle.id]

        guard let multiRaster = rasterizeCanvasView(view) else {
            XCTFail("Expected rasterized canvas for multi-selection")
            return
        }
        var foundMultiDashedBorder = false
        let rectBox = rectItem.nonTextSelectionBox
        for step in 2...18 {
            let edgeX = rectBox.minX + rectBox.width * (CGFloat(step) / 20.0)
            for dy in -2...2 {
                let probe = CGPoint(x: edgeX, y: rectBox.maxY + CGFloat(dy))
                guard let edgeRGBA = multiRaster.pixelRGBA(at: probe) else { continue }
                let isLightBlue = Int(edgeRGBA.b) > Int(edgeRGBA.r) + 60 && edgeRGBA.b >= 120
                if isLightBlue && edgeRGBA.a >= 80 {
                    foundMultiDashedBorder = true
                }
            }
        }
        XCTAssertTrue(foundMultiDashedBorder)

        if let suppressedCorner = multiRaster.pixelRGBA(at: rectItem.selectionScaleHandleCenters[0]) {
            let isWhiteFillRG = suppressedCorner.r >= 220 && suppressedCorner.g >= 220
            let isWhiteFillBA = suppressedCorner.b >= 220 && suppressedCorner.a >= 200
            XCTAssertFalse(isWhiteFillRG && isWhiteFillBA)
        }

        canvas.annotations = [rectItem]
        canvas.selectedIDs = [rectItem.id]
        let undoBeforeZeroDrag = canvas.undoStack.count
        let zeroHandle = canvas.annotations[0].selectionScaleHandleCenters[2]
        performMouseDrag(StrokeDragSpec(start: zeroHandle, end: zeroHandle), on: target)
        XCTAssertEqual(canvas.annotations[0], rectItem)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeZeroDrag)

        let undoBeforeRectScale = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: zeroHandle,
                end: CGPoint(x: zeroHandle.x + 40, y: zeroHandle.y + 25),
                midpoints: [
                    CGPoint(x: zeroHandle.x + 15, y: zeroHandle.y + 10),
                    CGPoint(x: zeroHandle.x + 28, y: zeroHandle.y + 18)
                ]
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeRectScale + 1)
        XCTAssertEqual(canvas.annotations[0].boundingRect.minX, 100, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.minY, 100, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.width, 160, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.height, 105, accuracy: 1e-6)
        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].boundingRect, CGRect(x: 100, y: 100, width: 120, height: 80))
        canvas.redo()
        XCTAssertEqual(canvas.annotations[0].boundingRect, CGRect(x: 100, y: 100, width: 160, height: 105))

        canvas.selectedIDs = [rectItem.id]
        let rectBottomRight = canvas.annotations[0].selectionScaleHandleCenters[1]
        performMouseDrag(
            StrokeDragSpec(
                start: rectBottomRight,
                end: CGPoint(x: rectBottomRight.x + 30, y: rectBottomRight.y - 10),
                modifiers: [.shift]
            ),
            on: target
        )
        XCTAssertEqual(
            canvas.annotations[0].boundingRect.width,
            canvas.annotations[0].boundingRect.height,
            accuracy: 1e-6
        )
        XCTAssertEqual(canvas.annotations[0].boundingRect.minX, 100, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.maxY, 205, accuracy: 1e-6)

        let circleItem = AnnotationItem(
            mode: .circle,
            startPoint: CGPoint(x: 60, y: 60),
            endPoint: CGPoint(x: 140, y: 120),
            strokeColor: .green,
            lineWeight: 3.0
        )
        canvas.annotations = [circleItem]
        canvas.selectedIDs = [circleItem.id]
        let circleBottomLeft = circleItem.selectionScaleHandleCenters[0]
        let undoBeforeCircleScale = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: circleBottomLeft,
                end: CGPoint(x: circleBottomLeft.x - 20, y: circleBottomLeft.y - 15),
                midpoints: [CGPoint(x: circleBottomLeft.x - 10, y: circleBottomLeft.y - 8)]
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeCircleScale + 1)
        XCTAssertEqual(canvas.annotations[0].boundingRect.maxX, 140, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.maxY, 120, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.minX, 40, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.minY, 45, accuracy: 1e-6)

        let blurItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 80, y: 80),
            endPoint: CGPoint(x: 180, y: 150),
            strokeColor: .red,
            blurStyle: .gaussian,
            blurOpacity: 0.55
        )
        canvas.annotations = [blurItem]
        canvas.selectedIDs = [blurItem.id]
        view.syncBackdropBlurViews()
        let blurTopLeft = blurItem.selectionScaleHandleCenters[3]
        let undoBeforeBlurScale = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: blurTopLeft,
                end: CGPoint(x: blurTopLeft.x - 30, y: blurTopLeft.y + 20)
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeBlurScale + 1)
        XCTAssertEqual(canvas.annotations[0].boundingRect, CGRect(x: 50, y: 80, width: 130, height: 90))
        XCTAssertEqual(view.backdropBlurViews[blurItem.id]?.frame, CGRect(x: 50, y: 80, width: 130, height: 90))

        let diagonalArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 50, y: 60), CGPoint(x: 150, y: 140)],
            startPoint: CGPoint(x: 50, y: 60),
            endPoint: CGPoint(x: 150, y: 140),
            strokeColor: .red,
            lineWeight: 4.0
        )
        canvas.annotations = [diagonalArrow]
        canvas.selectedIDs = [diagonalArrow.id]
        let diagTopRight = diagonalArrow.tipHandleCenter
        let undoBeforeDiagArrow = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: diagTopRight,
                end: CGPoint(x: diagTopRight.x + 50, y: diagTopRight.y + 40),
                midpoints: [CGPoint(x: diagTopRight.x + 25, y: diagTopRight.y + 20)]
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeDiagArrow + 1)
        XCTAssertEqual(canvas.annotations[0].startPoint, CGPoint(x: 50, y: 60))
        XCTAssertEqual(canvas.annotations[0].endPoint.x, 200, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint.y, 180, accuracy: 1e-6)

        let horizontalArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 60, y: 200), CGPoint(x: 160, y: 200)],
            startPoint: CGPoint(x: 60, y: 200),
            endPoint: CGPoint(x: 160, y: 200),
            strokeColor: .red,
            lineWeight: 4.0
        )
        canvas.annotations = [horizontalArrow]
        canvas.selectedIDs = [horizontalArrow.id]
        let horizHeadHandle = horizontalArrow.tipHandleCenter
        let undoBeforeHorizHead = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: horizHeadHandle,
                end: CGPoint(x: horizHeadHandle.x + 60, y: horizHeadHandle.y)
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeHorizHead + 1)
        XCTAssertEqual(canvas.annotations[0].startPoint.x, 60, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.y, 200, accuracy: 1e-6)
        XCTAssertGreaterThan(canvas.annotations[0].endPoint.x, 205)
        XCTAssertEqual(canvas.annotations[0].endPoint.y, 200, accuracy: 1e-6)

        let anchoredHeadX = canvas.annotations[0].endPoint.x
        let horizTailHandle = canvas.annotations[0].tailHandleCenter
        performMouseDrag(
            StrokeDragSpec(
                start: horizTailHandle,
                end: CGPoint(x: horizTailHandle.x - 35, y: horizTailHandle.y)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].endPoint.x, anchoredHeadX, accuracy: 1e-6)
        XCTAssertLessThan(canvas.annotations[0].startPoint.x, 35)

        let verticalArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 300, y: 80), CGPoint(x: 300, y: 180)],
            startPoint: CGPoint(x: 300, y: 80),
            endPoint: CGPoint(x: 300, y: 180),
            strokeColor: .red,
            lineWeight: 4.0
        )
        canvas.annotations = [verticalArrow]
        canvas.selectedIDs = [verticalArrow.id]
        let vertHeadHandle = verticalArrow.tipHandleCenter
        performMouseDrag(
            StrokeDragSpec(
                start: vertHeadHandle,
                end: CGPoint(x: vertHeadHandle.x, y: vertHeadHandle.y + 55)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].startPoint.x, 300, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.y, 80, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint.x, 300, accuracy: 1e-6)
        XCTAssertGreaterThan(canvas.annotations[0].endPoint.y, 225)

        let freeHandItem = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 50, y: 50), CGPoint(x: 90, y: 110), CGPoint(x: 130, y: 70)],
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 130, y: 70),
            strokeColor: .orange,
            lineWeight: 4.0
        )
        canvas.annotations = [freeHandItem]
        canvas.selectedIDs = [freeHandItem.id]
        let fhTopRight = freeHandItem.selectionScaleHandleCenters[2]
        let undoBeforeFreeHand = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: fhTopRight,
                end: CGPoint(x: fhTopRight.x + 40, y: fhTopRight.y + 30)
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeFreeHand + 1)
        XCTAssertEqual(canvas.annotations[0].points[0], CGPoint(x: 50, y: 50))
        XCTAssertEqual(canvas.annotations[0].points[1].x, 110, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].points[1].y, 140, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].points[2].x, 170, accuracy: 1e-6)

        let highlighterCurve = AnnotationItem(
            mode: .highlighter,
            points: [CGPoint(x: 60, y: 220), CGPoint(x: 110, y: 260), CGPoint(x: 160, y: 230)],
            startPoint: CGPoint(x: 60, y: 220),
            endPoint: CGPoint(x: 160, y: 230),
            strokeColor: PresentifyCore.RGBColor.yellow.withAlpha(0.42),
            lineWeight: 16.0,
            isHighlighter: true
        )
        canvas.annotations = [highlighterCurve]
        canvas.selectedIDs = [highlighterCurve.id]
        let hlBottomRight = highlighterCurve.selectionScaleHandleCenters[1]
        performMouseDrag(
            StrokeDragSpec(
                start: hlBottomRight,
                end: CGPoint(x: hlBottomRight.x + 50, y: hlBottomRight.y - 20)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].points[0].x, 60, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].points[1].y, 260, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].points[2].x, 210, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].points[0].y, 200, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].strokeColor.alpha, 0.42, accuracy: 1e-6)
    }

    func testTrackpadMagnifyStrokeLineWeightShortcutsControlsAndOrphanCornerScaleRecovery() {
        let settings = AppSettings(defaults: testDefaults)
        settings.annotateSaveSession = false
        settings.lineWeight = 6.0
        settings.currentDrawMode = .blur
        let shortcuts = ShortcutManager(defaults: testDefaults)
        let canvas = AnnotationCanvasState()
        let overlay = AnnotateOverlayController(settings: settings, shortcutManager: shortcuts, canvasState: canvas)
        overlay.showAnnotation()
        defer { overlay.hideAnnotation() }

        guard let panel = overlay.panel, let view = overlay.canvasView else {
            XCTFail("Expected overlay panel and canvasView")
            return
        }
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)

        let rectItem = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 100, y: 100),
            endPoint: CGPoint(x: 200, y: 160),
            strokeColor: .red,
            lineWeight: 6.0
        )
        let freeHandItem = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 40, y: 40), CGPoint(x: 80, y: 80)],
            startPoint: CGPoint(x: 40, y: 40),
            endPoint: CGPoint(x: 80, y: 80),
            strokeColor: .blue,
            lineWeight: 6.0
        )
        let blurItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 240, y: 80),
            endPoint: CGPoint(x: 320, y: 150),
            strokeColor: .red,
            blurStyle: .gaussian,
            blurOpacity: 0.55
        )
        canvas.annotations = [rectItem, freeHandItem, blurItem]
        canvas.selectedIDs = [rectItem.id, freeHandItem.id]

        let undoBeforePinch = canvas.undoStack.count
        let pinchBegan = SyntheticTrackpadEvent()
        pinchBegan.stubPhase = .began
        pinchBegan.stubMagnification = 0.25
        view.magnify(with: pinchBegan)

        let pinchChanged = SyntheticTrackpadEvent()
        pinchChanged.stubPhase = .changed
        pinchChanged.stubMagnification = 0.20
        view.magnify(with: pinchChanged)

        let pinchEnded = SyntheticTrackpadEvent()
        pinchEnded.stubPhase = .ended
        pinchEnded.stubMagnification = 0.0
        view.magnify(with: pinchEnded)

        XCTAssertEqual(canvas.undoStack.count, undoBeforePinch + 1)
        XCTAssertEqual(canvas.annotations[0].boundingRect.midX, 150, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].boundingRect.midY, 130, accuracy: 1e-6)
        XCTAssertGreaterThan(canvas.annotations[0].boundingRect.width, 145)
        XCTAssertGreaterThan(canvas.annotations[0].boundingRect.height, 85)
        XCTAssertEqual(canvas.annotations[1].boundingRect.midX, 60, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].boundingRect.midY, 60, accuracy: 1e-6)
        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].boundingRect, rectItem.boundingRect)

        canvas.selectedIDs = [rectItem.id, freeHandItem.id]
        XCTAssertFalse(controls.isAdjustingBlurOpacity)
        XCTAssertFalse(controls.isAdjustingTextSize)
        XCTAssertEqual(controls.displayedLineWeight, 6.0, accuracy: 1e-6)

        let undoBeforeIncreaseKey = canvas.undoStack.count
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(settings.lineWeight, 8.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 8.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 8.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeIncreaseKey + 1)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(settings.lineWeight, 6.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 6.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 6.0, accuracy: 1e-6)

        let ctrlOptModifiers = NSEvent.ModifierFlags([.control, .option]).rawValue
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x15, modifiers: ctrlOptModifiers))
        XCTAssertEqual(canvas.annotations[0].lineWeight, settings.lineWeight, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, settings.lineWeight, accuracy: 1e-6)

        controls.increaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, settings.lineWeight, accuracy: 1e-6)
        controls.decreaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, settings.lineWeight, accuracy: 1e-6)

        canvas.selectedIDs = [blurItem.id]
        XCTAssertTrue(controls.isAdjustingBlurOpacity)

        canvas.selectedIDs = [rectItem.id]
        let orphanHandle = canvas.annotations[0].selectionScaleHandleCenters[2]
        let undoBeforeOrphanDrag = canvas.undoStack.count
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: orphanHandle), in: panel))
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(
                    type: .leftMouseDragged,
                    location: CGPoint(x: orphanHandle.x + 25, y: orphanHandle.y + 18)
                ),
                in: panel
            )
        )
        XCTAssertTrue(view.hasActiveMouseInteraction)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeOrphanDrag + 1)

        panel.resignKey()
        XCTAssertFalse(view.hasActiveMouseInteraction)

        canvas.moveSelectedAnnotations(by: CGSize(width: 8, height: 6))
        XCTAssertEqual(canvas.undoStack.count, undoBeforeOrphanDrag + 2)

        let secondHandle = canvas.annotations[0].selectionScaleHandleCenters[0]
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: secondHandle), in: panel))
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(
                    type: .leftMouseDragged,
                    location: CGPoint(x: secondHandle.x - 12, y: secondHandle.y - 10)
                ),
                in: panel
            )
        )
        XCTAssertTrue(view.hasActiveMouseInteraction)
        view.cancelActiveInteraction()
        XCTAssertFalse(view.hasActiveMouseInteraction)
    }

    func testNonFiniteColorScaleAndLineWeightInputsPreserveFiniteSessionRoundTrip() {
        let canvas = AnnotationCanvasState()
        let rectItem = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 40, y: 50),
            endPoint: CGPoint(x: 140, y: 120),
            strokeColor: .red,
            lineWeight: 5.0
        )
        let arrowItem = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 50, y: 160), CGPoint(x: 150, y: 200)],
            startPoint: CGPoint(x: 50, y: 160),
            endPoint: CGPoint(x: 150, y: 200),
            strokeColor: .blue,
            lineWeight: 5.0
        )
        let freeHandItem = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 60, y: 60), CGPoint(x: 95, y: 110), CGPoint(x: 130, y: 80)],
            startPoint: CGPoint(x: 60, y: 60),
            endPoint: CGPoint(x: 130, y: 80),
            strokeColor: .green,
            lineWeight: 5.0
        )
        let highlighterItem = AnnotationItem(
            mode: .highlighter,
            points: [CGPoint(x: 70, y: 230), CGPoint(x: 180, y: 230)],
            startPoint: CGPoint(x: 70, y: 230),
            endPoint: CGPoint(x: 180, y: 230),
            strokeColor: PresentifyCore.RGBColor.yellow.withAlpha(0.42),
            lineWeight: 16.0,
            isHighlighter: true
        )
        let textItem = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 200, y: 80),
            endPoint: CGPoint(x: 200, y: 80),
            strokeColor: .white,
            text: "Finite Check",
            fontSize: 28.0
        )
        let blurItem = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 200, y: 150),
            endPoint: CGPoint(x: 280, y: 220),
            strokeColor: .red,
            blurStyle: .gaussian,
            blurOpacity: 0.55,
            blurTintColor: .white
        )

        canvas.annotations = [rectItem, arrowItem, freeHandItem, highlighterItem, textItem, blurItem]
        canvas.selectedIDs = Set(canvas.annotations.map(\.id))

        let nonFiniteInitColor = PresentifyCore.RGBColor(red: .nan, green: .infinity, blue: -.infinity, alpha: .nan)
        var mutatedNonFiniteColor = PresentifyCore.RGBColor.red
        mutatedNonFiniteColor.red = .nan
        mutatedNonFiniteColor.green = .infinity
        mutatedNonFiniteColor.blue = -.infinity
        mutatedNonFiniteColor.alpha = .nan
        let badGradient = GradientPair(startColor: mutatedNonFiniteColor, endColor: nonFiniteInitColor)
        canvas.applyColorUpdate(AnnotationColorUpdate(color: mutatedNonFiniteColor, gradient: badGradient))

        for item in canvas.annotations {
            let finiteRG = item.strokeColor.red.isFinite && item.strokeColor.green.isFinite
            let finiteBA = item.strokeColor.blue.isFinite && item.strokeColor.alpha.isFinite
            XCTAssertTrue(finiteRG && finiteBA)
            if let grad = item.gradientPair {
                let finiteStart = grad.startColor.red.isFinite && grad.startColor.green.isFinite
                let finiteEnd = grad.endColor.blue.isFinite && grad.endColor.alpha.isFinite
                XCTAssertTrue(finiteStart && finiteEnd)
            }
            if let tint = item.blurTintColor {
                let finiteTintRG = tint.red.isFinite && tint.green.isFinite
                let finiteTintBA = tint.blue.isFinite && tint.alpha.isFinite
                XCTAssertTrue(finiteTintRG && finiteTintBA)
            }
        }

        for badItem in [canvas.annotations[0], canvas.annotations[1], canvas.annotations[2]] {
            canvas.applyCornerScale(
                AnnotationCornerScaleRequest(
                    anchor: AnnotationCornerScaleAnchor(initialItem: badItem, cornerIndex: 2),
                    motion: AnnotationCornerScaleMotion(
                        dragStartPoint: CGPoint(x: CGFloat.nan, y: 100),
                        currentPoint: CGPoint(x: 200, y: CGFloat.infinity)
                    )
                )
            )
            canvas.applyCornerScale(
                AnnotationCornerScaleRequest(
                    anchor: AnnotationCornerScaleAnchor(initialItem: badItem, cornerIndex: 99),
                    motion: AnnotationCornerScaleMotion(
                        dragStartPoint: CGPoint(x: 100, y: 100),
                        currentPoint: CGPoint(x: 160, y: 160)
                    )
                )
            )
            canvas.applyCornerScale(
                AnnotationCornerScaleRequest(
                    anchor: AnnotationCornerScaleAnchor(
                        initialItem: badItem,
                        cornerIndex: 2
                    ),
                    motion: AnnotationCornerScaleMotion(
                        dragStartPoint: badItem.selectionScaleHandleCenters[2],
                        currentPoint: CGPoint(x: 1_000_000, y: -1_000_000)
                    )
                ).withConstraint(.uniform)
            )
        }

        for factor in [Double.nan, Double.infinity, -Double.infinity, 0.0, -4.0, 1_000_000.0] {
            canvas.scaleSelectedAnnotations(by: factor)
        }

        for badWeight in [Double.nan, Double.infinity, -Double.infinity, -25.0, 999.0] {
            canvas.updateSelectedStrokeLineWeight(badWeight)
        }

        for item in canvas.annotations {
            let finiteStart = item.startPoint.x.isFinite && item.startPoint.y.isFinite
            let finiteEnd = item.endPoint.x.isFinite && item.endPoint.y.isFinite
            XCTAssertTrue(finiteStart && finiteEnd)
            XCTAssertLessThanOrEqual(abs(item.startPoint.x), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.startPoint.y), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.endPoint.x), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.endPoint.y), 32_768.0)
            for pt in item.points {
                XCTAssertTrue(pt.x.isFinite && pt.y.isFinite)
                XCTAssertLessThanOrEqual(abs(pt.x), 32_768.0)
                XCTAssertLessThanOrEqual(abs(pt.y), 32_768.0)
            }
            XCTAssertTrue(item.lineWeight.isFinite)
            if item.mode.supportsStrokeLineWeight {
                XCTAssertGreaterThanOrEqual(item.lineWeight, 1.0)
                XCTAssertLessThanOrEqual(item.lineWeight, 64.0)
            }
            XCTAssertTrue(item.fontSize.isFinite)
        }

        guard let exported = canvas.exportSessionData() else {
            XCTFail("Expected session export data after non-finite stress")
            return
        }
        let restored = AnnotationCanvasState()
        XCTAssertTrue(restored.importSessionData(exported))
        XCTAssertEqual(restored.annotations.count, canvas.annotations.count)
    }

    func testPostDrawHighlighterAndMismatchedSelectedStrokeWeightStepAcrossFullRangeWithUndo() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        let target = (window: window, view: view)
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)

        var observedWeights: [Double] = []
        view.onLineWeightChanged = { observedWeights.append($0) }

        settings.minLineWeight = 2.0
        settings.maxLineWeight = 24.0
        settings.lineWeight = 6.0
        settings.currentDrawMode = .highlighter

        performMouseDrag(
            StrokeDragSpec(
                start: CGPoint(x: 60, y: 120),
                end: CGPoint(x: 220, y: 120),
                midpoints: [CGPoint(x: 140, y: 120)]
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 1)
        let highlighterID = canvas.annotations[0].id
        XCTAssertEqual(canvas.selectedIDs, [highlighterID])
        XCTAssertTrue(view.isPostDrawAutoSelection)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 14.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 14.0, accuracy: 1e-6)

        controls.increaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 16.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 16.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 16.0, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 14.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 14.0, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 12.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 12.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 12.0, accuracy: 1e-6)

        let mismatchedStroke = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 80, y: 180), CGPoint(x: 150, y: 210), CGPoint(x: 210, y: 185)],
            startPoint: CGPoint(x: 80, y: 180),
            endPoint: CGPoint(x: 210, y: 185),
            strokeColor: .red,
            lineWeight: 20.0
        )
        canvas.annotations = [mismatchedStroke]
        canvas.selectedIDs = [mismatchedStroke.id]
        settings.lineWeight = 4.0
        XCTAssertEqual(controls.displayedLineWeight, 20.0, accuracy: 1e-6)

        let undoBeforeStepUp = canvas.undoStack.count
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 22.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 22.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 22.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 22.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeStepUp + 1)

        controls.increaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 24.0, accuracy: 1e-6)
        controls.increaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 26.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 26.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 24.0, accuracy: 1e-6)

        for _ in 0..<19 {
            XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        }
        XCTAssertEqual(canvas.annotations[0].lineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 64.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 24.0, accuracy: 1e-6)

        let undoAtCeiling = canvas.undoStack.count
        controls.increaseLineWeight()
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoAtCeiling)

        for _ in 0..<31 {
            XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        }
        XCTAssertEqual(canvas.annotations[0].lineWeight, 2.0, accuracy: 1e-6)

        controls.decreaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 2.0, accuracy: 1e-6)

        let undoAtFloor = canvas.undoStack.count
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        controls.decreaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoAtFloor)

        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 2.0, accuracy: 1e-6)
        canvas.redo()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 1.0, accuracy: 1e-6)
    }

    func testTouchDrawPostDrawAutoSelectionRecolorAndConsecutiveTouchStroke() {
        let harness = makeCanvasHarness()
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)

        settings.isTouchDrawActive = true
        settings.currentDrawMode = .freeHand
        controls.selectFavoriteColor(at: 0)

        let makeSingleTouchEvent: (NSString, (NSTouch.Phase, NSPoint)) -> SyntheticTrackpadEvent = { id, sample in
            let touch = SyntheticTouch()
            touch.stubIdentity = id
            touch.stubPhase = sample.0
            touch.stubNormalizedPosition = sample.1
            let event = SyntheticTrackpadEvent()
            event.stubTouches = [touch]
            return event
        }

        view.touchesBegan(with: makeSingleTouchEvent("touch-1", (.began, NSPoint(x: 0.20, y: 0.30))))
        view.touchesMoved(with: makeSingleTouchEvent("touch-1", (.moved, NSPoint(x: 0.35, y: 0.40))))
        view.touchesMoved(with: makeSingleTouchEvent("touch-1", (.moved, NSPoint(x: 0.50, y: 0.35))))
        view.touchesEnded(with: makeSingleTouchEvent("touch-1", (.ended, NSPoint(x: 0.50, y: 0.35))))

        XCTAssertEqual(canvas.annotations.count, 1)
        let firstID = canvas.annotations[0].id
        let firstSnapshot = canvas.annotations[0]
        XCTAssertEqual(canvas.selectedIDs, [firstID])
        XCTAssertTrue(view.isPostDrawAutoSelection)

        controls.selectFavoriteColor(at: 2)
        let expectedRecolor = settings.favColors[2]
        XCTAssertEqual(canvas.annotations[0].strokeColor, expectedRecolor)

        view.touchesBegan(with: makeSingleTouchEvent("touch-2", (.began, NSPoint(x: 0.20, y: 0.30))))
        XCTAssertTrue(canvas.selectedIDs.isEmpty)
        XCTAssertFalse(view.isPostDrawAutoSelection)
        XCTAssertNotNil(canvas.activeDraft)

        view.touchesMoved(with: makeSingleTouchEvent("touch-2", (.moved, NSPoint(x: 0.60, y: 0.65))))
        view.touchesEnded(with: makeSingleTouchEvent("touch-2", (.ended, NSPoint(x: 0.72, y: 0.60))))

        XCTAssertEqual(canvas.annotations.count, 2)
        let secondID = canvas.annotations[1].id
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(canvas.selectedIDs, [secondID])
        XCTAssertTrue(view.isPostDrawAutoSelection)
        XCTAssertEqual(canvas.annotations[0].startPoint, firstSnapshot.startPoint)
        XCTAssertEqual(canvas.annotations[0].endPoint, firstSnapshot.endPoint)
    }

    func testDoubleClickInlineTextRecolorSingleUndoEscapeRestoreAndSingleRandomSample() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)

        let item = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 80, y: 120),
            endPoint: CGPoint(x: 80, y: 120),
            strokeColor: .white,
            text: "Original Label",
            fontSize: 28.0
        )
        canvas.annotations = [item]
        canvas.selectedIDs = [item.id]
        let baselineUndo = canvas.undoStack.count

        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: item.textCenter, clickCount: 2),
                in: window
            )
        )
        XCTAssertNotNil(view.activeTextField)
        XCTAssertEqual(canvas.selectedIDs, [item.id])
        XCTAssertEqual(canvas.activeInlineEditingID, item.id)

        controls.selectFavoriteColor(at: 1)
        XCTAssertEqual(view.activeTextField?.textColor, settings.activeStrokeColor.nsColor)
        XCTAssertEqual(canvas.annotations[0].strokeColor, .white)
        XCTAssertEqual(canvas.undoStack.count, baselineUndo)

        controls.selectRandomColors()
        let previewRandomColor = settings.activeGradient.startColor
        XCTAssertEqual(view.activeTextField?.textColor, previewRandomColor.nsColor)
        XCTAssertEqual(canvas.annotations[0].strokeColor, .white)
        XCTAssertEqual(canvas.undoStack.count, baselineUndo)

        CustomColorPanelBridge.shared.present(for: settings, canvasState: canvas)
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.90, green: 0.25, blue: 0.20))
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.20, green: 0.70, blue: 0.85))
        XCTAssertEqual(view.activeTextField?.textColor, settings.activeStrokeColor.nsColor)
        XCTAssertEqual(canvas.annotations[0].strokeColor, .white)
        XCTAssertEqual(canvas.undoStack.count, baselineUndo)

        view.activeTextField?.stringValue = "Discarded Draft"
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x35, modifiers: 0))
        XCTAssertNil(view.activeTextField)
        XCTAssertNil(canvas.activeInlineEditingID)
        XCTAssertEqual(canvas.annotations[0].text, "Original Label")
        XCTAssertEqual(canvas.annotations[0].strokeColor, .white)
        XCTAssertEqual(canvas.undoStack.count, baselineUndo)

        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: canvas.annotations[0].textCenter, clickCount: 2),
                in: window
            )
        )
        XCTAssertNotNil(view.activeTextField)

        controls.selectRandomColors()
        let committedRandomSample = settings.activeGradient.startColor
        XCTAssertEqual(view.activeTextField?.textColor, committedRandomSample.nsColor)
        XCTAssertEqual(canvas.undoStack.count, baselineUndo)

        view.activeTextField?.stringValue = "Random Committed"
        view.commitActiveTextEditing()
        XCTAssertEqual(canvas.undoStack.count, baselineUndo + 1)
        XCTAssertEqual(canvas.annotations[0].text, "Random Committed")
        XCTAssertEqual(canvas.annotations[0].strokeColor, committedRandomSample)

        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].text, "Original Label")
        XCTAssertEqual(canvas.annotations[0].strokeColor, .white)

        settings.currentDrawMode = .text
        let undoBeforePanelCommit = canvas.undoStack.count
        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: canvas.annotations[0].textCenter, clickCount: 2),
                in: window
            )
        )
        XCTAssertNotNil(view.activeTextField)

        CustomColorPanelBridge.shared.present(for: settings, canvasState: canvas)
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.85, green: 0.30, blue: 0.22))
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.24, green: 0.55, blue: 0.92))
        sendColorPanelColor(PresentifyCore.RGBColor(red: 0.15, green: 0.76, blue: 0.48))
        let finalPanelColor = settings.activeStrokeColor
        XCTAssertEqual(view.activeTextField?.textColor, finalPanelColor.nsColor)
        XCTAssertEqual(canvas.annotations[0].strokeColor, .white)
        XCTAssertEqual(canvas.undoStack.count, undoBeforePanelCommit)

        view.activeTextField?.stringValue = "Panel Committed"
        view.commitActiveTextEditing()
        CustomColorPanelBridge.shared.close()

        XCTAssertEqual(canvas.undoStack.count, undoBeforePanelCommit + 1)
        XCTAssertEqual(canvas.annotations[0].text, "Panel Committed")
        XCTAssertEqual(canvas.annotations[0].strokeColor, finalPanelColor)

        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].text, "Original Label")
        XCTAssertEqual(canvas.annotations[0].strokeColor, .white)
    }

    func testScalingWideNearEdgeTextWithBlurRedactionClampsSessionCoordinatesAndRoundTrips() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let target = (window: window, view: view)

        let wideText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: 200, y: 200),
            endPoint: CGPoint(x: 200, y: 200),
            strokeColor: .white,
            text: String(repeating: "W", count: 800),
            fontSize: 12.0
        )
        let nearEdgeText = AnnotationItem(
            mode: .text,
            startPoint: CGPoint(x: -32_700, y: 32_700),
            endPoint: CGPoint(x: -32_700, y: 32_700),
            strokeColor: .yellow,
            text: String(repeating: "M", count: 400),
            fontSize: 14.0
        )
        let blurRedaction = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 40, y: 50),
            endPoint: CGPoint(x: 180, y: 140),
            strokeColor: .red,
            blurStyle: .pixelate,
            blurOpacity: 0.85,
            blurTintColor: .blue
        )

        canvas.annotations = [wideText, nearEdgeText, blurRedaction]
        canvas.selectedIDs = [wideText.id]

        let topRightHandle = wideText.localTextScaleHandleCenters[2]
        let textCenter = wideText.textCenter
        let initialDist = hypot(topRightHandle.x - textCenter.x, topRightHandle.y - textCenter.y)
        let farDragTarget = CGPoint(x: textCenter.x + initialDist * 20.0, y: textCenter.y + 400.0)
        performMouseDrag(
            StrokeDragSpec(start: topRightHandle, end: farDragTarget),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].fontSize, 200.0, accuracy: 1e-6)
        XCTAssertLessThanOrEqual(abs(canvas.annotations[0].startPoint.x), 32_768.0)
        XCTAssertLessThanOrEqual(abs(canvas.annotations[0].startPoint.y), 32_768.0)
        XCTAssertLessThanOrEqual(abs(canvas.annotations[0].endPoint.x), 32_768.0)
        XCTAssertLessThanOrEqual(abs(canvas.annotations[0].endPoint.y), 32_768.0)

        canvas.selectedIDs = [nearEdgeText.id]
        let magBegan = SyntheticTrackpadEvent()
        magBegan.stubPhase = .began
        magBegan.stubMagnification = 4.0
        view.magnify(with: magBegan)

        let magChanged = SyntheticTrackpadEvent()
        magChanged.stubPhase = .changed
        magChanged.stubMagnification = 16.0
        view.magnify(with: magChanged)

        let magEnded = SyntheticTrackpadEvent()
        magEnded.stubPhase = .ended
        magEnded.stubMagnification = 0.0
        view.magnify(with: magEnded)

        XCTAssertEqual(canvas.annotations[1].fontSize, 200.0, accuracy: 1e-6)
        for item in canvas.annotations {
            XCTAssertTrue(item.startPoint.x.isFinite && item.startPoint.y.isFinite)
            XCTAssertTrue(item.endPoint.x.isFinite && item.endPoint.y.isFinite)
            XCTAssertLessThanOrEqual(abs(item.startPoint.x), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.startPoint.y), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.endPoint.x), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.endPoint.y), 32_768.0)
            for pt in item.points {
                XCTAssertTrue(pt.x.isFinite && pt.y.isFinite)
                XCTAssertLessThanOrEqual(abs(pt.x), 32_768.0)
                XCTAssertLessThanOrEqual(abs(pt.y), 32_768.0)
            }
        }

        guard let exported = canvas.exportSessionData() else {
            XCTFail("Expected exported session data after scaling wide text to 200pt")
            return
        }
        let restored = AnnotationCanvasState()
        XCTAssertTrue(restored.importSessionData(exported))
        XCTAssertEqual(restored.annotations.count, 3)

        guard let restoredBlur = restored.annotations.first(where: { $0.id == blurRedaction.id }) else {
            XCTFail("Expected blur redaction to survive session import")
            return
        }
        XCTAssertEqual(restoredBlur.mode, .blur)
        XCTAssertEqual(restoredBlur.boundingRect, blurRedaction.boundingRect)
        XCTAssertEqual(restoredBlur.blurStyle, .pixelate)
        XCTAssertEqual(restoredBlur.blurOpacity ?? 0.0, 0.85, accuracy: 1e-6)
        XCTAssertEqual(restoredBlur.blurTintColor, .blue)
    }

    func testMixedSelectionSelectAllStepsStrokeAndHighlighterAcrossFullRangeWithUndo() {
        let harness = makeCanvasHarness()
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)

        var observedWeights: [Double] = []
        view.onLineWeightChanged = { observedWeights.append($0) }

        settings.minLineWeight = 2.0
        settings.maxLineWeight = 24.0
        settings.lineWeight = 6.0
        settings.annotateFontSize = 24.0
        settings.blurOpacity = 0.55

        let heavyStroke = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 40, y: 60), CGPoint(x: 120, y: 90), CGPoint(x: 200, y: 70)],
            startPoint: CGPoint(x: 40, y: 60),
            endPoint: CGPoint(x: 200, y: 70),
            strokeColor: .red,
            lineWeight: 26.0
        )
        let highlighterStroke = AnnotationItem(
            mode: .highlighter,
            points: [CGPoint(x: 40, y: 130), CGPoint(x: 180, y: 130)],
            startPoint: CGPoint(x: 40, y: 130),
            endPoint: CGPoint(x: 180, y: 130),
            strokeColor: RGBColor.yellow.withAlpha(0.42),
            lineWeight: 14.0,
            isHighlighter: true
        )
        let textNote = AnnotationItem(
            mode: .text,
            points: [CGPoint(x: 50, y: 200)],
            startPoint: CGPoint(x: 50, y: 200),
            endPoint: CGPoint(x: 50, y: 200),
            strokeColor: .blue,
            lineWeight: 2.0,
            text: "Mixed Selection",
            fontSize: 30.0
        )
        let blurRegion = AnnotationItem(
            mode: .blur,
            startPoint: CGPoint(x: 220, y: 60),
            endPoint: CGPoint(x: 340, y: 160),
            strokeColor: .green,
            lineWeight: 6.0,
            blurStyle: .gaussian,
            blurOpacity: 0.45
        )
        canvas.annotations = [heavyStroke, highlighterStroke, textNote, blurRegion]

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x00, modifiers: KeyBinding.commandMask))
        XCTAssertEqual(canvas.selectedIDs, Set(canvas.annotations.map(\.id)))
        XCTAssertFalse(controls.isAdjustingTextSize)
        XCTAssertFalse(controls.isAdjustingBlurOpacity)
        XCTAssertEqual(controls.displayedLineWeight, 26.0, accuracy: 1e-6)

        let undoBeforeFirstPlus = canvas.undoStack.count
        controls.increaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 28.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 16.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[2].fontSize, 30.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[3].effectiveBlurOpacity, 0.45, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 28.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 8.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeFirstPlus + 1)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 30.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 18.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 30.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 30.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 10.0, accuracy: 1e-6)

        controls.decreaseLineWeight()
        XCTAssertEqual(canvas.annotations[0].lineWeight, 28.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 16.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 28.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 8.0, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 26.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 14.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 26.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 26.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 6.0, accuracy: 1e-6)

        for _ in 0..<10 {
            controls.increaseLineWeight()
        }
        for _ in 0..<9 {
            XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        }
        XCTAssertEqual(canvas.annotations[0].lineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 52.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 64.0, accuracy: 1e-6)

        for _ in 0..<3 {
            controls.increaseLineWeight()
            XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        }
        XCTAssertEqual(canvas.annotations[0].lineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 64.0, accuracy: 1e-6)

        let undoAtCeiling = canvas.undoStack.count
        controls.increaseLineWeight()
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 64.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 64.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoAtCeiling)

        for _ in 0..<16 {
            XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        }
        for _ in 0..<15 {
            controls.decreaseLineWeight()
        }
        XCTAssertEqual(canvas.annotations[0].lineWeight, 2.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 2.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 2.0, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 1.0, accuracy: 1e-6)

        let undoAtFloor = canvas.undoStack.count
        controls.decreaseLineWeight()
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x21, modifiers: 0))
        XCTAssertEqual(canvas.annotations[0].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.undoStack.count, undoAtFloor)

        canvas.undo()
        XCTAssertTrue(canvas.selectedIDs.isEmpty)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 2.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 2.0, accuracy: 1e-6)

        canvas.redo()
        XCTAssertTrue(canvas.selectedIDs.isEmpty)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[1].lineWeight, 1.0, accuracy: 1e-6)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x00, modifiers: KeyBinding.commandMask))
        XCTAssertEqual(controls.displayedLineWeight, 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[2].fontSize, 30.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[3].effectiveBlurOpacity, 0.45, accuracy: 1e-6)

        let soloHighlighter = AnnotationItem(
            mode: .highlighter,
            points: [CGPoint(x: 40, y: 240), CGPoint(x: 190, y: 240)],
            startPoint: CGPoint(x: 40, y: 240),
            endPoint: CGPoint(x: 190, y: 240),
            strokeColor: RGBColor.yellow.withAlpha(0.42),
            lineWeight: 14.0,
            isHighlighter: true
        )
        canvas.annotations = [textNote, soloHighlighter, blurRegion]
        settings.lineWeight = 6.0
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x00, modifiers: KeyBinding.commandMask))
        XCTAssertEqual(controls.displayedLineWeight, 14.0, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x1E, modifiers: 0))
        XCTAssertEqual(canvas.annotations[1].lineWeight, 16.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 16.0, accuracy: 1e-6)
        XCTAssertEqual(observedWeights.last ?? -1.0, 16.0, accuracy: 1e-6)
        XCTAssertEqual(settings.lineWeight, 8.0, accuracy: 1e-6)

        controls.increaseLineWeight()
        XCTAssertEqual(canvas.annotations[1].lineWeight, 18.0, accuracy: 1e-6)
        XCTAssertEqual(controls.displayedLineWeight, 18.0, accuracy: 1e-6)

        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x06, modifiers: KeyBinding.commandMask))
        XCTAssertEqual(canvas.annotations[1].lineWeight, 16.0, accuracy: 1e-6)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x06, modifiers: KeyBinding.commandMask))
        XCTAssertEqual(canvas.annotations[1].lineWeight, 14.0, accuracy: 1e-6)
        XCTAssertTrue(view.handleKeyCommand(keyCode: 0x06, modifiers: KeyBinding.commandMask | KeyBinding.shiftMask))
        XCTAssertEqual(canvas.annotations[1].lineWeight, 16.0, accuracy: 1e-6)
    }

    func testDirectionalHandlesExposeThreeNonOverlappingGripsSnapEndpointsAndHitTestWidePolygons() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        settings.isWhiteboardActive = false
        settings.dimScreenOnAnnotate = false
        settings.annotateToolIndicator = false
        let target = (window: window, view: view)

        let thinStraightLine = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 60, y: 120), CGPoint(x: 120, y: 120)],
            startPoint: CGPoint(x: 60, y: 120),
            endPoint: CGPoint(x: 120, y: 120),
            isConstrained: true,
            strokeColor: .green,
            lineWeight: 2.0
        )
        let straightHighlighter = AnnotationItem(
            mode: .highlighter,
            points: [CGPoint(x: 60, y: 160), CGPoint(x: 140, y: 160)],
            startPoint: CGPoint(x: 60, y: 160),
            endPoint: CGPoint(x: 140, y: 160),
            isConstrained: true,
            strokeColor: PresentifyCore.RGBColor.yellow.withAlpha(0.42),
            lineWeight: 2.0,
            isHighlighter: true
        )
        let curvedFreeHand = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 60, y: 60), CGPoint(x: 90, y: 80), CGPoint(x: 120, y: 65)],
            startPoint: CGPoint(x: 60, y: 60),
            endPoint: CGPoint(x: 120, y: 65),
            strokeColor: .orange,
            lineWeight: 4.0
        )
        let arrowItem = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 70, y: 140), CGPoint(x: 210, y: 140)],
            startPoint: CGPoint(x: 70, y: 140),
            endPoint: CGPoint(x: 210, y: 140),
            strokeColor: .yellow,
            lineWeight: 6.0
        )

        XCTAssertTrue(thinStraightLine.isConstrainedStraightLine)
        XCTAssertTrue(thinStraightLine.usesDirectionalHandles)
        XCTAssertTrue(straightHighlighter.isConstrainedStraightLine)
        XCTAssertTrue(straightHighlighter.usesDirectionalHandles)
        XCTAssertFalse(curvedFreeHand.isConstrainedStraightLine)
        XCTAssertFalse(curvedFreeHand.usesDirectionalHandles)
        XCTAssertFalse(arrowItem.isConstrainedStraightLine)
        XCTAssertTrue(arrowItem.usesDirectionalHandles)

        for directional in [arrowItem, thinStraightLine, straightHighlighter] {
            let grips = directional.directionalHandleCenters
            XCTAssertEqual(grips.count, 3)
            let d01 = hypot(Double(grips[0].x - grips[1].x), Double(grips[0].y - grips[1].y))
            let d12 = hypot(Double(grips[1].x - grips[2].x), Double(grips[1].y - grips[2].y))
            let d02 = hypot(Double(grips[0].x - grips[2].x), Double(grips[0].y - grips[2].y))
            XCTAssertGreaterThanOrEqual(d01, 12.0)
            XCTAssertGreaterThanOrEqual(d12, 12.0)
            XCTAssertGreaterThanOrEqual(d02, 12.0)
        }

        canvas.annotations = [arrowItem]
        canvas.selectedIDs = [arrowItem.id]
        guard let singleArrowRaster = rasterizeCanvasView(view),
              let tailRGBA = singleArrowRaster.pixelRGBA(at: arrowItem.tailHandleCenter),
              let tipRGBA = singleArrowRaster.pixelRGBA(at: arrowItem.tipHandleCenter),
              let headGripRGBA = singleArrowRaster.pixelRGBA(at: arrowItem.headScaleHandleCenter) else {
            XCTFail("Expected rasterized directional handles on single-selected arrow")
            return
        }
        let tailBrightRG = tailRGBA.r >= 220 && tailRGBA.g >= 220
        let tailBrightBA = tailRGBA.b >= 220 && tailRGBA.a >= 200
        XCTAssertTrue(tailBrightRG && tailBrightBA)
        let tipBrightRG = tipRGBA.r >= 220 && tipRGBA.g >= 220
        let tipBrightBA = tipRGBA.b >= 220 && tipRGBA.a >= 200
        XCTAssertTrue(tipBrightRG && tipBrightBA)
        let isSkyBlueGrip = headGripRGBA.b >= 180 && Int(headGripRGBA.b) > Int(headGripRGBA.r) + 60
        XCTAssertTrue(isSkyBlueGrip && headGripRGBA.a >= 180)

        for py in 100...180 {
            for px in 55...225 {
                guard let sample = singleArrowRaster.pixelRGBA(at: CGPoint(x: px, y: py)) else { continue }
                let hasHighRB = sample.r >= 110 && sample.b >= 140
                let dominatesGreen = Int(sample.r) > Int(sample.g) + 45 && Int(sample.b) > Int(sample.g) + 45
                XCTAssertFalse(hasHighRB && dominatesGreen)
            }
        }

        canvas.annotations = [arrowItem, thinStraightLine]
        canvas.selectedIDs = [arrowItem.id, thinStraightLine.id]
        guard let multiDirRaster = rasterizeCanvasView(view) else {
            XCTFail("Expected rasterized multi-selected directional items")
            return
        }
        if let suppressedGrip = multiDirRaster.pixelRGBA(at: arrowItem.headScaleHandleCenter) {
            let stillSkyBlue = suppressedGrip.b >= 180 && Int(suppressedGrip.b) > Int(suppressedGrip.r) + 60
            XCTAssertFalse(stillSkyBlue && suppressedGrip.a >= 180)
        }

        let wideBoxArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 60, y: 150), CGPoint(x: 220, y: 150)],
            startPoint: CGPoint(x: 60, y: 150),
            endPoint: CGPoint(x: 220, y: 150),
            strokeColor: .red,
            lineWeight: 6.0,
            headWidth: 96.0
        )
        canvas.annotations = [wideBoxArrow]
        canvas.selectedIDs = [wideBoxArrow.id]
        let unusedTopLeftCorner = wideBoxArrow.selectionScaleHandleCenters[3]
        performMouseDrag(
            StrokeDragSpec(
                start: unusedTopLeftCorner,
                end: CGPoint(x: unusedTopLeftCorner.x - 20, y: unusedTopLeftCorner.y + 20)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations.first?.id, wideBoxArrow.id)
        XCTAssertEqual(canvas.annotations[0].startPoint, wideBoxArrow.startPoint)
        XCTAssertEqual(canvas.annotations[0].endPoint, wideBoxArrow.endPoint)

        canvas.annotations = [arrowItem]
        canvas.selectedIDs = [arrowItem.id]
        let undoBeforeRedirect = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: arrowItem.tipHandleCenter,
                end: CGPoint(x: 190, y: 215),
                midpoints: [
                    CGPoint(x: 205, y: 165),
                    CGPoint(x: 198, y: 190)
                ]
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeRedirect + 1)
        XCTAssertEqual(canvas.annotations[0].startPoint, CGPoint(x: 70, y: 140))
        XCTAssertEqual(canvas.annotations[0].endPoint.x, 190, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint.y, 215, accuracy: 1e-6)
        canvas.undo()
        XCTAssertEqual(canvas.annotations[0].endPoint, CGPoint(x: 210, y: 140))
        canvas.redo()
        XCTAssertEqual(canvas.annotations[0].endPoint, CGPoint(x: 190, y: 215))

        canvas.selectedIDs = [arrowItem.id]
        let currentTip = canvas.annotations[0].tipHandleCenter
        performMouseDrag(
            StrokeDragSpec(
                start: currentTip,
                end: CGPoint(x: 170, y: 232),
                modifiers: [.shift]
            ),
            on: target
        )
        let snappedDX = canvas.annotations[0].endPoint.x - canvas.annotations[0].startPoint.x
        let snappedDY = canvas.annotations[0].endPoint.y - canvas.annotations[0].startPoint.y
        XCTAssertEqual(snappedDX, snappedDY, accuracy: 1e-5)

        let anchoredTip = canvas.annotations[0].endPoint
        performMouseDrag(
            StrokeDragSpec(
                start: canvas.annotations[0].tailHandleCenter,
                end: CGPoint(x: anchoredTip.x - 110, y: anchoredTip.y + 8),
                modifiers: [.shift]
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].endPoint.x, anchoredTip.x, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint.y, anchoredTip.y, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.y, anchoredTip.y, accuracy: 1e-5)

        let clampArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 100, y: 140), CGPoint(x: 200, y: 140)],
            startPoint: CGPoint(x: 100, y: 140),
            endPoint: CGPoint(x: 200, y: 140),
            strokeColor: .blue,
            lineWeight: 6.0
        )
        canvas.annotations = [clampArrow]
        canvas.selectedIDs = [clampArrow.id]
        performMouseDrag(
            StrokeDragSpec(
                start: clampArrow.tipHandleCenter,
                end: CGPoint(x: 102, y: 140)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].startPoint, CGPoint(x: 100, y: 140))
        XCTAssertEqual(canvas.annotations[0].endPoint.x, 108, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint.y, 140, accuracy: 1e-6)

        performMouseDrag(
            StrokeDragSpec(
                start: canvas.annotations[0].tailHandleCenter,
                end: CGPoint(x: 106, y: 140)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].endPoint.x, 108, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.x, 100, accuracy: 1e-6)

        canvas.annotations = [thinStraightLine]
        canvas.selectedIDs = [thinStraightLine.id]
        performMouseDrag(
            StrokeDragSpec(
                start: thinStraightLine.tipHandleCenter,
                end: CGPoint(x: 165, y: 193)
            ),
            on: target
        )
        XCTAssertTrue(canvas.annotations[0].isConstrained)
        XCTAssertTrue(canvas.annotations[0].isConstrainedStraightLine)
        XCTAssertEqual(canvas.annotations[0].points, [CGPoint(x: 60, y: 120), CGPoint(x: 165, y: 193)])

        let beforeCancelTip = canvas.annotations[0].tipHandleCenter
        view.mouseDown(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDown, location: beforeCancelTip),
                in: window
            )
        )
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: 210, y: 210)),
                in: window
            )
        )
        view.cancelActiveInteraction()
        let postCancelPoint = canvas.annotations[0].endPoint
        view.mouseDragged(
            with: makeMouseEvent(
                SyntheticMouseSpec(type: .leftMouseDragged, location: CGPoint(x: 250, y: 80)),
                in: window
            )
        )
        XCTAssertEqual(canvas.annotations[0].endPoint, postCancelPoint)

        let hugeWingArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 60, y: 150), CGPoint(x: 260, y: 150)],
            startPoint: CGPoint(x: 60, y: 150),
            endPoint: CGPoint(x: 260, y: 150),
            strokeColor: .red,
            lineWeight: 6.0,
            headWidth: 160.0
        )
        let hugeWedgeLine = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 60, y: 150), CGPoint(x: 260, y: 150)],
            startPoint: CGPoint(x: 60, y: 150),
            endPoint: CGPoint(x: 260, y: 150),
            isConstrained: true,
            strokeColor: .blue,
            lineWeight: 6.0,
            headWidth: 160.0
        )
        XCTAssertGreaterThanOrEqual(hugeWingArrow.boundingRect.height, 159.0)
        XCTAssertGreaterThanOrEqual(hugeWedgeLine.boundingRect.height, 159.0)

        canvas.annotations = [hugeWingArrow]
        XCTAssertEqual(canvas.hitTestAnnotation(at: CGPoint(x: 180, y: 195), tolerance: 2.0), hugeWingArrow.id)
        XCTAssertNil(canvas.hitTestAnnotation(at: CGPoint(x: 80, y: 195), tolerance: 2.0))
        canvas.selectAnnotations(in: CGRect(x: 175, y: 190, width: 15, height: 15))
        XCTAssertEqual(canvas.selectedIDs, [hugeWingArrow.id])
        canvas.selectAnnotations(in: CGRect(x: 70, y: 190, width: 20, height: 20))
        XCTAssertTrue(canvas.selectedIDs.isEmpty)

        canvas.annotations = [hugeWedgeLine]
        XCTAssertEqual(canvas.hitTestAnnotation(at: CGPoint(x: 245, y: 210), tolerance: 2.0), hugeWedgeLine.id)
        XCTAssertNil(canvas.hitTestAnnotation(at: CGPoint(x: 75, y: 210), tolerance: 2.0))
        canvas.selectAnnotations(in: CGRect(x: 240, y: 205, width: 12, height: 15))
        XCTAssertEqual(canvas.selectedIDs, [hugeWedgeLine.id])
        canvas.selectAnnotations(in: CGRect(x: 70, y: 205, width: 15, height: 15))
        XCTAssertTrue(canvas.selectedIDs.isEmpty)
    }

    func testHeadWidthHandleScalesTaperedPolygonsPinchMagnifyAndStrokeWeightInvariants() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let target = (window: window, view: view)

        let baseArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 60, y: 150), CGPoint(x: 240, y: 150)],
            startPoint: CGPoint(x: 60, y: 150),
            endPoint: CGPoint(x: 240, y: 150),
            strokeColor: .red,
            lineWeight: 6.0
        )
        let classicVerts = baseArrow.arrowPolygonPoints()
        XCTAssertEqual(classicVerts.count, 7)
        XCTAssertEqual(abs(classicVerts[0].y - 150.0), 3.0, accuracy: 1e-6)
        XCTAssertEqual(abs(classicVerts[1].y - 150.0), 3.0, accuracy: 1e-6)

        canvas.annotations = [baseArrow]
        canvas.selectedIDs = [baseArrow.id]
        let initialHeadGrip = baseArrow.headScaleHandleCenter
        let undoBeforeHeadScale = canvas.undoStack.count
        performMouseDrag(
            StrokeDragSpec(
                start: initialHeadGrip,
                end: CGPoint(x: initialHeadGrip.x, y: 195),
                midpoints: [CGPoint(x: initialHeadGrip.x, y: 175)]
            ),
            on: target
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeHeadScale + 1)
        XCTAssertEqual(canvas.annotations[0].startPoint, baseArrow.startPoint)
        XCTAssertEqual(canvas.annotations[0].endPoint, baseArrow.endPoint)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 90.0, accuracy: 1e-4)

        let taperedVerts = canvas.annotations[0].arrowPolygonPoints()
        XCTAssertEqual(taperedVerts.count, 7)
        let tailHW = abs(Double(taperedVerts[0].y) - 150.0)
        let neckHW = abs(Double(taperedVerts[1].y) - 150.0)
        let headHW = abs(Double(taperedVerts[2].y) - 150.0)
        XCTAssertLessThan(tailHW, neckHW)
        XCTAssertLessThan(neckHW, headHW)
        XCTAssertLessThan(taperedVerts[2].x, taperedVerts[1].x)

        performMouseDrag(
            StrokeDragSpec(
                start: canvas.annotations[0].headScaleHandleCenter,
                end: CGPoint(x: 180, y: 380)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 240.0, accuracy: 1e-6)

        performMouseDrag(
            StrokeDragSpec(
                start: canvas.annotations[0].headScaleHandleCenter,
                end: CGPoint(x: 180, y: 150)
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 8.0, accuracy: 1e-6)
        let minVerts = canvas.annotations[0].arrowPolygonPoints()
        let minTailHW = abs(Double(minVerts[0].y) - 150.0)
        let minNeckHW = abs(Double(minVerts[1].y) - 150.0)
        let minHeadHW = abs(Double(minVerts[2].y) - 150.0)
        XCTAssertLessThan(minTailHW, minNeckHW)
        XCTAssertLessThan(minNeckHW, minHeadHW)

        let straightLine = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 60, y: 150), CGPoint(x: 240, y: 150)],
            startPoint: CGPoint(x: 60, y: 150),
            endPoint: CGPoint(x: 240, y: 150),
            isConstrained: true,
            strokeColor: .blue,
            lineWeight: 6.0
        )
        XCTAssertFalse(straightLine.usesTaperedWedgeLine)
        canvas.annotations = [straightLine]
        canvas.selectedIDs = [straightLine.id]
        let lineGrip = straightLine.headScaleHandleCenter
        performMouseDrag(
            StrokeDragSpec(
                start: lineGrip,
                end: CGPoint(x: lineGrip.x, y: 190)
            ),
            on: target
        )
        XCTAssertTrue(canvas.annotations[0].usesTaperedWedgeLine)
        XCTAssertTrue(canvas.annotations[0].isConstrained)
        XCTAssertEqual(canvas.annotations[0].points.count, 2)
        let wedgeVerts = canvas.annotations[0].taperedLinePolygonPoints()
        XCTAssertEqual(wedgeVerts.count, 4)
        let wedgeTailHW = abs(Double(wedgeVerts[0].y) - 150.0)
        let wedgeHeadHW = abs(Double(wedgeVerts[1].y) - 150.0)
        XCTAssertLessThan(wedgeTailHW, wedgeHeadHW)

        let pinchArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 80, y: 120), CGPoint(x: 200, y: 120)],
            startPoint: CGPoint(x: 80, y: 120),
            endPoint: CGPoint(x: 200, y: 120),
            strokeColor: .red,
            lineWeight: 6.0,
            headWidth: 60.0
        )
        let pinchLine = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 80, y: 190), CGPoint(x: 200, y: 190)],
            startPoint: CGPoint(x: 80, y: 190),
            endPoint: CGPoint(x: 200, y: 190),
            isConstrained: true,
            strokeColor: .green,
            lineWeight: 6.0,
            headWidth: 40.0
        )
        canvas.annotations = [pinchArrow, pinchLine]
        canvas.selectedIDs = [pinchArrow.id, pinchLine.id]
        let undoBeforePinch = canvas.undoStack.count

        let pinchBegan = SyntheticTrackpadEvent()
        pinchBegan.stubPhase = .began
        pinchBegan.stubMagnification = 0.5
        view.magnify(with: pinchBegan)

        let pinchEnded = SyntheticTrackpadEvent()
        pinchEnded.stubPhase = .ended
        pinchEnded.stubMagnification = 0.0
        view.magnify(with: pinchEnded)

        XCTAssertEqual(canvas.undoStack.count, undoBeforePinch + 1)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 90.0, accuracy: 1e-4)
        XCTAssertEqual(canvas.annotations[1].headWidth ?? 0.0, 60.0, accuracy: 1e-4)
        XCTAssertTrue(canvas.annotations[1].isConstrained)
        XCTAssertEqual(canvas.annotations[1].points.count, 2)

        canvas.scaleSelectedAnnotations(by: 10.0)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 240.0, accuracy: 1e-6)
        canvas.scaleSelectedAnnotations(by: 0.02)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 8.0, accuracy: 1e-6)

        let weightArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 60, y: 140), CGPoint(x: 220, y: 140)],
            startPoint: CGPoint(x: 60, y: 140),
            endPoint: CGPoint(x: 220, y: 140),
            strokeColor: .red,
            lineWeight: 6.0,
            headWidth: 12.0
        )
        canvas.annotations = [weightArrow]
        canvas.selectedIDs = [weightArrow.id]
        _ = canvas.adjustSelectedStrokeLineWeight(by: 10.0)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 16.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 22.4, accuracy: 1e-6)

        canvas.updateSelectedStrokeLineWeight(30.0)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 30.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0, accuracy: 1e-6)

        _ = canvas.adjustSelectedStrokeLineWeight(by: -10.0)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 20.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0, accuracy: 1e-6)
    }

    func testArrowTailFadeSettingToolbarToggleDraftInheritanceRenderingAndCodableMigration() throws {
        let firstSettings = AppSettings(defaults: testDefaults)
        XCTAssertFalse(firstSettings.annotateArrowTailFade)
        firstSettings.annotateArrowTailFade = true

        let reloadedSettings = AppSettings(defaults: testDefaults)
        XCTAssertTrue(reloadedSettings.annotateArrowTailFade)
        reloadedSettings.restoreDefaults()
        XCTAssertFalse(reloadedSettings.annotateArrowTailFade)
        XCTAssertFalse(AppSettings(defaults: testDefaults).annotateArrowTailFade)

        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        settings.isWhiteboardActive = false
        settings.dimScreenOnAnnotate = false
        settings.annotateToolIndicator = false
        let controls = AnnotateControlsView(settings: settings, canvasState: canvas)
        let target = (window: window, view: view)

        for directionalMode in [DrawMode.arrow, .freeHand, .highlighter] {
            settings.currentDrawMode = directionalMode
            XCTAssertTrue(controls.showsTailFadeToggle)
        }
        for otherMode in [DrawMode.rectangle, .circle, .text, .blur] {
            settings.currentDrawMode = otherMode
            XCTAssertFalse(controls.showsTailFadeToggle)
        }

        let arrowItem = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 40, y: 120), CGPoint(x: 200, y: 120)],
            startPoint: CGPoint(x: 40, y: 120),
            endPoint: CGPoint(x: 200, y: 120),
            strokeColor: .red,
            lineWeight: 8.0
        )
        let rectItem = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 40, y: 180),
            endPoint: CGPoint(x: 140, y: 230),
            strokeColor: .blue,
            lineWeight: 4.0
        )
        canvas.annotations = [arrowItem, rectItem]
        settings.currentDrawMode = .arrow
        canvas.selectedIDs = [rectItem.id]
        XCTAssertFalse(controls.showsTailFadeToggle)

        canvas.selectedIDs = [arrowItem.id, rectItem.id]
        XCTAssertTrue(controls.showsTailFadeToggle)
        XCTAssertFalse(controls.isTailFadeToggleActive)

        let undoBeforeToggle = canvas.undoStack.count
        controls.toggleArrowTailFade()
        XCTAssertTrue(settings.annotateArrowTailFade)
        XCTAssertTrue(controls.isTailFadeToggleActive)
        XCTAssertTrue(canvas.annotations[0].tailFadeEnabled)
        XCTAssertFalse(canvas.annotations[1].tailFadeEnabled)
        XCTAssertEqual(canvas.undoStack.count, undoBeforeToggle + 1)

        canvas.undo()
        XCTAssertFalse(canvas.annotations[0].tailFadeEnabled)
        canvas.redo()
        XCTAssertTrue(canvas.annotations[0].tailFadeEnabled)

        canvas.selectedIDs = [arrowItem.id]
        canvas.activeInlineEditingID = arrowItem.id
        canvas.applySelectedTailFade(.disabled)
        XCTAssertTrue(canvas.annotations[0].tailFadeEnabled)
        canvas.activeInlineEditingID = nil
        controls.toggleArrowTailFade()
        XCTAssertFalse(settings.annotateArrowTailFade)
        XCTAssertFalse(canvas.annotations[0].tailFadeEnabled)

        canvas.annotations.removeAll()
        canvas.selectedIDs.removeAll()
        settings.annotateArrowTailFade = true

        settings.currentDrawMode = .arrow
        performMouseDrag(
            StrokeDragSpec(start: CGPoint(x: 40, y: 80), end: CGPoint(x: 180, y: 80)),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 1)
        XCTAssertTrue(canvas.annotations[0].tailFadeEnabled)

        settings.currentDrawMode = .freeHand
        performMouseDrag(
            StrokeDragSpec(
                start: CGPoint(x: 40, y: 120),
                end: CGPoint(x: 180, y: 120),
                modifiers: [.shift]
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 2)
        XCTAssertTrue(canvas.annotations[1].isConstrainedStraightLine)
        XCTAssertTrue(canvas.annotations[1].tailFadeEnabled)
        XCTAssertTrue(canvas.annotations[1].usesTaperedWedgeLine)

        performMouseDrag(
            StrokeDragSpec(
                start: CGPoint(x: 40, y: 160),
                end: CGPoint(x: 180, y: 170),
                midpoints: [
                    CGPoint(x: 90, y: 205),
                    CGPoint(x: 135, y: 145)
                ]
            ),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 3)
        XCTAssertFalse(canvas.annotations[2].usesDirectionalHandles)
        XCTAssertFalse(canvas.annotations[2].tailFadeEnabled)
        XCTAssertNil(canvas.annotations[2].headWidth)

        settings.currentDrawMode = .rectangle
        performMouseDrag(
            StrokeDragSpec(start: CGPoint(x: 40, y: 210), end: CGPoint(x: 140, y: 250)),
            on: target
        )
        XCTAssertEqual(canvas.annotations.count, 4)
        XCTAssertFalse(canvas.annotations[3].tailFadeEnabled)

        let fadedRedArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 40, y: 150), CGPoint(x: 260, y: 150)],
            startPoint: CGPoint(x: 40, y: 150),
            endPoint: CGPoint(x: 260, y: 150),
            strokeColor: .red,
            lineWeight: 12.0,
            headWidth: 56.0,
            tailFadeEnabled: true
        )
        canvas.annotations = [fadedRedArrow]
        canvas.selectedIDs.removeAll()
        guard let fadedRaster = rasterizeCanvasView(view),
              let nearTailRGBA = fadedRaster.pixelRGBA(at: CGPoint(x: 46, y: 150)),
              let nearHeadRGBA = fadedRaster.pixelRGBA(at: CGPoint(x: 235, y: 150)) else {
            XCTFail("Expected rasterized tail-faded arrow")
            return
        }
        XCTAssertGreaterThanOrEqual(nearHeadRGBA.a, 210)
        XCTAssertLessThanOrEqual(nearTailRGBA.a, 45)
        XCTAssertGreaterThan(Int(nearHeadRGBA.a), Int(nearTailRGBA.a) + 150)

        var foundWhiteRimOnHead = false
        for dy in -30...30 {
            for dx in 230...259 {
                guard let px = fadedRaster.pixelRGBA(at: CGPoint(x: dx, y: 150 + dy)) else { continue }
                let hasWhiteRimChannels = px.g >= 90 && px.b >= 90
                if hasWhiteRimChannels && px.a >= 120 {
                    foundWhiteRimOnHead = true
                }
            }
        }
        XCTAssertTrue(foundWhiteRimOnHead)

        let gradientFadedArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 40, y: 80), CGPoint(x: 250, y: 80)],
            startPoint: CGPoint(x: 40, y: 80),
            endPoint: CGPoint(x: 250, y: 80),
            strokeColor: .blue,
            gradientPair: GradientPair(startColor: .blue, endColor: .green),
            lineWeight: 10.0,
            headWidth: 48.0,
            tailFadeEnabled: true
        )
        let highlighterFadedArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 40, y: 160), CGPoint(x: 250, y: 160)],
            startPoint: CGPoint(x: 40, y: 160),
            endPoint: CGPoint(x: 250, y: 160),
            strokeColor: PresentifyCore.RGBColor.yellow.withAlpha(0.42),
            lineWeight: 12.0,
            isHighlighter: true,
            headWidth: 48.0,
            tailFadeEnabled: true
        )
        let fadedWedgeLine = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 40, y: 230), CGPoint(x: 250, y: 230)],
            startPoint: CGPoint(x: 40, y: 230),
            endPoint: CGPoint(x: 250, y: 230),
            isConstrained: true,
            strokeColor: .blue,
            lineWeight: 10.0,
            headWidth: 44.0,
            tailFadeEnabled: true
        )
        canvas.annotations = [gradientFadedArrow, highlighterFadedArrow, fadedWedgeLine]
        guard let comboRaster = rasterizeCanvasView(view),
              let gradTail = comboRaster.pixelRGBA(at: CGPoint(x: 46, y: 80)),
              let gradHead = comboRaster.pixelRGBA(at: CGPoint(x: 230, y: 80)),
              let hlTail = comboRaster.pixelRGBA(at: CGPoint(x: 46, y: 160)),
              let hlHead = comboRaster.pixelRGBA(at: CGPoint(x: 230, y: 160)),
              let wedgeTail = comboRaster.pixelRGBA(at: CGPoint(x: 46, y: 230)),
              let wedgeHead = comboRaster.pixelRGBA(at: CGPoint(x: 242, y: 230)) else {
            XCTFail("Expected rasterized gradient, highlighter, and wedge tail-faded items")
            return
        }
        XCTAssertGreaterThan(Int(gradHead.a), Int(gradTail.a) + 140)
        XCTAssertGreaterThan(Int(hlHead.a), Int(hlTail.a) + 40)
        XCTAssertLessThan(hlHead.a, 180)
        XCTAssertGreaterThan(Int(wedgeHead.a), Int(wedgeTail.a) + 140)

        XCTAssertEqual(AnnotationItem.sanitizeHeadWidth(.nan), 28.0, accuracy: 1e-6)
        XCTAssertEqual(AnnotationItem.sanitizeHeadWidth(.infinity), 28.0, accuracy: 1e-6)
        XCTAssertEqual(AnnotationItem.sanitizeHeadWidth(2.0), 8.0, accuracy: 1e-6)
        XCTAssertEqual(AnnotationItem.sanitizeHeadWidth(999.0), 240.0, accuracy: 1e-6)

        let baselineEncoded = try JSONEncoder().encode(arrowItem)
        var legacyDict = try XCTUnwrap(JSONSerialization.jsonObject(with: baselineEncoded) as? [String: Any])
        legacyDict.removeValue(forKey: "headWidth")
        legacyDict.removeValue(forKey: "tailFadeEnabled")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyDict)
        let decodedLegacy = try JSONDecoder().decode(AnnotationItem.self, from: legacyData)
        XCTAssertNil(decodedLegacy.headWidth)
        XCTAssertFalse(decodedLegacy.tailFadeEnabled)

        var overWideArrowDict = legacyDict
        overWideArrowDict["id"] = UUID().uuidString
        overWideArrowDict["headWidth"] = 5000.0
        overWideArrowDict["tailFadeEnabled"] = true

        var underWideArrowDict = legacyDict
        underWideArrowDict["id"] = UUID().uuidString
        underWideArrowDict["headWidth"] = -15.0
        underWideArrowDict["tailFadeEnabled"] = false

        let rectEncoded = try JSONEncoder().encode(rectItem)
        var dirtyRectDict = try XCTUnwrap(JSONSerialization.jsonObject(with: rectEncoded) as? [String: Any])
        dirtyRectDict["headWidth"] = 120.0
        dirtyRectDict["tailFadeEnabled"] = true

        let sessionArrayData = try JSONSerialization.data(
            withJSONObject: [overWideArrowDict, underWideArrowDict, dirtyRectDict]
        )
        let importedCanvas = AnnotationCanvasState()
        XCTAssertTrue(importedCanvas.importSessionData(sessionArrayData))
        XCTAssertEqual(importedCanvas.annotations.count, 3)
        XCTAssertEqual(importedCanvas.annotations[0].headWidth ?? 0.0, 240.0, accuracy: 1e-6)
        XCTAssertTrue(importedCanvas.annotations[0].tailFadeEnabled)
        XCTAssertEqual(importedCanvas.annotations[1].headWidth ?? 0.0, 8.0, accuracy: 1e-6)
        XCTAssertFalse(importedCanvas.annotations[1].tailFadeEnabled)
        XCTAssertNil(importedCanvas.annotations[2].headWidth)
        XCTAssertFalse(importedCanvas.annotations[2].tailFadeEnabled)
    }

    func testDirectionalHandleDragClampsCoordinatesResistsNonFiniteInputsAndPreservesSessionImport() {
        let canvas = AnnotationCanvasState()
        let arrowItem = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 100, y: 120), CGPoint(x: 240, y: 180)],
            startPoint: CGPoint(x: 100, y: 120),
            endPoint: CGPoint(x: 240, y: 180),
            strokeColor: .red,
            lineWeight: 6.0,
            headWidth: 36.0,
            tailFadeEnabled: true
        )
        let constrainedLine = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 80, y: 200), CGPoint(x: 220, y: 200)],
            startPoint: CGPoint(x: 80, y: 200),
            endPoint: CGPoint(x: 220, y: 200),
            isConstrained: true,
            strokeColor: .blue,
            lineWeight: 5.0,
            headWidth: 28.0,
            tailFadeEnabled: true
        )
        let rectItem = AnnotationItem(
            mode: .rectangle,
            startPoint: CGPoint(x: 40, y: 40),
            endPoint: CGPoint(x: 120, y: 90),
            strokeColor: .green,
            lineWeight: 4.0
        )
        canvas.annotations = [arrowItem, constrainedLine, rectItem]
        let undoBeforeInvalid = canvas.undoStack.count

        let badPoints: [CGPoint] = [
            CGPoint(x: CGFloat.nan, y: 100),
            CGPoint(x: 100, y: CGFloat.infinity),
            CGPoint(x: -CGFloat.infinity, y: CGFloat.nan)
        ]
        for handle in [AnnotationDirectionalHandle.tail, .headWidth, .tip] {
            for badPt in badPoints {
                canvas.applyDirectionalHandleDrag(
                    AnnotationDirectionalDragRequest(initialItem: arrowItem, handle: handle)
                        .at(badPt, angleSnap: .free)
                )
                canvas.applyDirectionalHandleDrag(
                    AnnotationDirectionalDragRequest(initialItem: constrainedLine, handle: handle)
                        .at(badPt, angleSnap: .fortyFiveDegrees)
                )
            }
            canvas.applyDirectionalHandleDrag(
                AnnotationDirectionalDragRequest(initialItem: rectItem, handle: handle)
                    .at(CGPoint(x: 200, y: 200), angleSnap: .free)
            )
        }

        var corruptedInitial = arrowItem
        corruptedInitial.startPoint = CGPoint(x: CGFloat.nan, y: 50)
        canvas.applyDirectionalHandleDrag(
            AnnotationDirectionalDragRequest(initialItem: corruptedInitial, handle: .tip)
                .at(CGPoint(x: 300, y: 300), angleSnap: .free)
        )
        XCTAssertEqual(canvas.undoStack.count, undoBeforeInvalid)

        canvas.applyDirectionalHandleDrag(
            AnnotationDirectionalDragRequest(initialItem: arrowItem, handle: .tip)
                .at(CGPoint(x: 900_000, y: -900_000), angleSnap: .free)
        )
        canvas.applyDirectionalHandleDrag(
            AnnotationDirectionalDragRequest(initialItem: canvas.annotations[0], handle: .tail)
                .at(CGPoint(x: -900_000, y: 900_000), angleSnap: .fortyFiveDegrees)
        )
        canvas.applyDirectionalHandleDrag(
            AnnotationDirectionalDragRequest(initialItem: canvas.annotations[0], handle: .headWidth)
                .at(CGPoint(x: 900_000, y: 900_000), angleSnap: .free)
        )
        canvas.applyDirectionalHandleDrag(
            AnnotationDirectionalDragRequest(initialItem: constrainedLine, handle: .tip)
                .at(CGPoint(x: -750_000, y: -750_000), angleSnap: .fortyFiveDegrees)
        )
        canvas.applyDirectionalHandleDrag(
            AnnotationDirectionalDragRequest(initialItem: canvas.annotations[1], handle: .headWidth)
                .at(CGPoint(x: 500_000, y: -500_000), angleSnap: .free)
        )

        for item in canvas.annotations {
            let finiteStart = item.startPoint.x.isFinite && item.startPoint.y.isFinite
            let finiteEnd = item.endPoint.x.isFinite && item.endPoint.y.isFinite
            XCTAssertTrue(finiteStart && finiteEnd)
            XCTAssertLessThanOrEqual(abs(item.startPoint.x), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.startPoint.y), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.endPoint.x), 32_768.0)
            XCTAssertLessThanOrEqual(abs(item.endPoint.y), 32_768.0)
            for pt in item.points {
                XCTAssertTrue(pt.x.isFinite && pt.y.isFinite)
                XCTAssertLessThanOrEqual(abs(pt.x), 32_768.0)
                XCTAssertLessThanOrEqual(abs(pt.y), 32_768.0)
            }
            for polyPt in item.arrowPolygonPoints() + item.taperedLinePolygonPoints() + item.directionalHandleCenters {
                XCTAssertTrue(polyPt.x.isFinite && polyPt.y.isFinite)
                XCTAssertLessThanOrEqual(abs(polyPt.x), 32_768.0)
                XCTAssertLessThanOrEqual(abs(polyPt.y), 32_768.0)
            }
            if let hw = item.headWidth {
                XCTAssertTrue(hw.isFinite)
                XCTAssertGreaterThanOrEqual(hw, 8.0)
                XCTAssertLessThanOrEqual(hw, 240.0)
            }
        }

        guard let exported = canvas.exportSessionData() else {
            XCTFail("Expected exported session data after extreme coordinate drags")
            return
        }
        let restored = AnnotationCanvasState()
        XCTAssertTrue(restored.importSessionData(exported))
        XCTAssertEqual(restored.annotations.count, canvas.annotations.count)
    }

    func testOffCenterDirectionalHandleGrabNonFiniteHeadWidthWeightSyncAndBoundedTailFadeCulling() {
        let harness = makeCanvasHarness()
        let window = harness.window
        let view = harness.view
        let canvas = harness.canvas
        let settings = harness.settings
        settings.isWhiteboardActive = false
        settings.dimScreenOnAnnotate = false
        settings.annotateToolIndicator = false

        let grabArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 80, y: 150), CGPoint(x: 240, y: 150)],
            startPoint: CGPoint(x: 80, y: 150),
            endPoint: CGPoint(x: 240, y: 150),
            strokeColor: .red,
            lineWeight: 6.0,
            headWidth: 40.0
        )
        canvas.annotations = [grabArrow]
        canvas.selectedIDs = [grabArrow.id]

        let tipCenter = canvas.annotations[0].tipHandleCenter
        let tipGrab = CGPoint(x: tipCenter.x + 3.0, y: tipCenter.y + 4.0)
        let tipFirstDrag = CGPoint(x: tipGrab.x + 1.0, y: tipGrab.y + 2.0)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: tipGrab), in: window))
        XCTAssertEqual(canvas.annotations[0].endPoint, tipCenter)
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: tipFirstDrag), in: window))
        XCTAssertEqual(canvas.annotations[0].startPoint, grabArrow.startPoint)
        XCTAssertEqual(canvas.annotations[0].endPoint.x, tipCenter.x + 1.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].endPoint.y, tipCenter.y + 2.0, accuracy: 1e-6)
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: tipFirstDrag), in: window))

        canvas.annotations = [grabArrow]
        canvas.selectedIDs = [grabArrow.id]
        let headCenter = canvas.annotations[0].headScaleHandleCenter
        let headGrab = CGPoint(x: headCenter.x, y: headCenter.y + 5.0)
        let headFirstDrag = CGPoint(x: headGrab.x, y: headGrab.y + 1.0)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: headGrab), in: window))
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 40.0, accuracy: 1e-6)
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: headFirstDrag), in: window))
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0, accuracy: 1e-4)
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: headFirstDrag), in: window))

        let tailCenter = canvas.annotations[0].tailHandleCenter
        let tailGrab = CGPoint(x: tailCenter.x - 4.0, y: tailCenter.y - 3.0)
        let tailFirstDrag = CGPoint(x: tailGrab.x - 2.0, y: tailGrab.y + 1.0)
        view.mouseDown(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDown, location: tailGrab), in: window))
        view.mouseDragged(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseDragged, location: tailFirstDrag), in: window))
        XCTAssertEqual(canvas.annotations[0].startPoint.x, tailCenter.x - 2.0, accuracy: 1e-6)
        XCTAssertEqual(canvas.annotations[0].startPoint.y, tailCenter.y + 1.0, accuracy: 1e-6)
        view.mouseUp(with: makeMouseEvent(SyntheticMouseSpec(type: .leftMouseUp, location: tailFirstDrag), in: window))

        var mutatedArrow = grabArrow
        mutatedArrow.lineWeight = 24.0
        canvas.annotations = [mutatedArrow]
        canvas.selectedIDs = [mutatedArrow.id]

        canvas.annotations[0].headWidth = .nan
        _ = canvas.adjustSelectedStrokeLineWeight(by: 6.0)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 30.0, accuracy: 1e-6)
        XCTAssertTrue((canvas.annotations[0].headWidth ?? .nan).isFinite)
        XCTAssertGreaterThanOrEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0, accuracy: 1e-6)

        canvas.annotations[0].lineWeight = 24.0
        canvas.annotations[0].headWidth = .infinity
        _ = canvas.adjustSelectedStrokeLineWeight(by: 6.0)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 30.0, accuracy: 1e-6)
        XCTAssertTrue((canvas.annotations[0].headWidth ?? .nan).isFinite)
        XCTAssertGreaterThanOrEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0, accuracy: 1e-6)

        canvas.annotations[0].lineWeight = 12.0
        canvas.annotations[0].headWidth = .nan
        canvas.updateSelectedStrokeLineWeight(30.0)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 30.0, accuracy: 1e-6)
        XCTAssertTrue((canvas.annotations[0].headWidth ?? .nan).isFinite)
        XCTAssertGreaterThanOrEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0, accuracy: 1e-6)

        canvas.annotations[0].headWidth = .infinity
        canvas.updateSelectedStrokeLineWeight(30.0)
        XCTAssertEqual(canvas.annotations[0].lineWeight, 30.0, accuracy: 1e-6)
        XCTAssertTrue((canvas.annotations[0].headWidth ?? .nan).isFinite)
        XCTAssertGreaterThanOrEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0)
        XCTAssertEqual(canvas.annotations[0].headWidth ?? 0.0, 42.0, accuracy: 1e-6)

        let offScreenFadedArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 30_000, y: 30_000), CGPoint(x: 30_220, y: 30_060)],
            startPoint: CGPoint(x: 30_000, y: 30_000),
            endPoint: CGPoint(x: 30_220, y: 30_060),
            strokeColor: .green,
            lineWeight: 14.0,
            headWidth: 64.0,
            tailFadeEnabled: true
        )
        let offScreenSolidArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: -30_000, y: -30_000), CGPoint(x: -29_800, y: -29_950)],
            startPoint: CGPoint(x: -30_000, y: -30_000),
            endPoint: CGPoint(x: -29_800, y: -29_950),
            strokeColor: .yellow,
            lineWeight: 10.0,
            headWidth: 48.0,
            tailFadeEnabled: false
        )
        let offScreenFadedWedge = AnnotationItem(
            mode: .freeHand,
            points: [CGPoint(x: 30_000, y: 29_500), CGPoint(x: 30_250, y: 29_500)],
            startPoint: CGPoint(x: 30_000, y: 29_500),
            endPoint: CGPoint(x: 30_250, y: 29_500),
            isConstrained: true,
            strokeColor: .blue,
            lineWeight: 10.0,
            headWidth: 50.0,
            tailFadeEnabled: true
        )
        let partialTailOffScreenArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: -80, y: 180), CGPoint(x: 180, y: 180)],
            startPoint: CGPoint(x: -80, y: 180),
            endPoint: CGPoint(x: 180, y: 180),
            strokeColor: .red,
            lineWeight: 12.0,
            headWidth: 52.0,
            tailFadeEnabled: true
        )
        let partialHeadOffScreenArrow = AnnotationItem(
            mode: .arrow,
            points: [CGPoint(x: 280, y: 260), CGPoint(x: 520, y: 260)],
            startPoint: CGPoint(x: 280, y: 260),
            endPoint: CGPoint(x: 520, y: 260),
            strokeColor: .blue,
            lineWeight: 12.0,
            headWidth: 52.0,
            tailFadeEnabled: true
        )

        canvas.annotations = [
            offScreenFadedArrow,
            offScreenSolidArrow,
            offScreenFadedWedge,
            partialTailOffScreenArrow,
            partialHeadOffScreenArrow
        ]
        canvas.selectedIDs.removeAll()

        guard let cachedRep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            XCTFail("Expected bitmapImageRepForCachingDisplay for canvas bounds")
            return
        }
        view.cacheDisplay(in: view.bounds, to: cachedRep)
        XCTAssertNotNil(cachedRep.cgImage)

        guard let raster = rasterizeCanvasView(view),
              let partialEntryRGBA = raster.pixelRGBA(at: CGPoint(x: 8, y: 180)),
              let partialHeadRGBA = raster.pixelRGBA(at: CGPoint(x: 160, y: 180)),
              let partialTailStartRGBA = raster.pixelRGBA(at: CGPoint(x: 290, y: 260)),
              let partialRightEdgeRGBA = raster.pixelRGBA(at: CGPoint(x: 412, y: 260)),
              let untouchedRGBA = raster.pixelRGBA(at: CGPoint(x: 200, y: 60)) else {
            XCTFail("Expected rasterized pixels for off-screen and partially on-screen faded arrows")
            return
        }
        XCTAssertGreaterThanOrEqual(partialHeadRGBA.a, 200)
        XCTAssertGreaterThanOrEqual(partialHeadRGBA.r, 180)
        XCTAssertGreaterThan(Int(partialHeadRGBA.a), Int(partialEntryRGBA.a) + 80)
        XCTAssertGreaterThan(Int(partialRightEdgeRGBA.a), Int(partialTailStartRGBA.a) + 40)
        XCTAssertEqual(untouchedRGBA.a, 0)
    }
}

