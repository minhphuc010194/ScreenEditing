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

        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.lineWeight, 20.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.cursorHighlightSize, 75.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.zoomLevel, 2.5, accuracy: 1e-6)

        reloaded.restoreDefaults()
        XCTAssertEqual(reloaded.lineWeight, 6.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.cursorHighlightSize, 60.0, accuracy: 1e-6)
        XCTAssertEqual(reloaded.zoomLevel, 2.0, accuracy: 1e-6)
    }

    func testShortcutManagerAll32DefaultBindingsAndCommandMatching() {
        XCTAssertEqual(ShortcutCommand.allCases.count, 32)
        XCTAssertEqual(ShortcutCategory.global.commands.count, 5)
        XCTAssertEqual(ShortcutCategory.annotate.commands.count, 22)
        XCTAssertEqual(ShortcutCategory.cursor.commands.count, 5)

        let manager = ShortcutManager(defaults: testDefaults)
        XCTAssertEqual(manager.binding(for: .toggleAnnotateScreen).displayString, "⌃⌥A")
        XCTAssertEqual(manager.binding(for: .toggleAnnotateControls).displayString, "⌃⌥W")
        XCTAssertEqual(manager.binding(for: .toggleHighlightCursor).displayString, "⌃⌥H")
        XCTAssertEqual(manager.binding(for: .toggleSpotlightCursor).displayString, "⌃⌥S")
        XCTAssertEqual(manager.binding(for: .toggleZoomCursor).displayString, "⌃⌥Z")
        XCTAssertEqual(manager.binding(for: .clearAnnotate).displayString, "Delete")
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
        XCTAssertEqual(SettingsView.copyrightText, "© Softal.io. All rights reserved.")
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
}
