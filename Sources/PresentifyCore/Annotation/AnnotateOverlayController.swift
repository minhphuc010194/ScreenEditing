import AppKit
import Combine
import CoreEngine
import SwiftUI

public final class AnnotatePanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.acceptsMouseMovedEvents = true
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { false }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let canvas = contentView as? AnnotateCanvasView,
           canvas.handleKeyCommand(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    public func updateBackground(from settings: AppSettings) {
        if settings.isWhiteboardActive {
            backgroundColor = settings.annotateWhiteboardColor.nsColor.withAlphaComponent(CGFloat(settings.whiteboardOpacity))
        } else if settings.dimScreenOnAnnotate {
            backgroundColor = NSColor.black.withAlphaComponent(CGFloat(settings.dimScreenOpacity))
        } else {
            backgroundColor = .clear
        }
    }
}

public final class AnnotateCanvasView: NSView, NSTextFieldDelegate {
    public let canvasState: AnnotationCanvasState
    public let settings: AppSettings
    public let shortcutManager: ShortcutManager
    public var onRequestSaveScreenshot: (() -> Void)?
    public var onRequestCopyScreenshot: (() -> Void)?
    public var onRequestClose: (() -> Void)?
    public var onRequestOpenSettings: (() -> Void)?
    public var onLineWeightChanged: ((Double) -> Void)?
    public var exclusionScreenRectsProvider: (() -> [NSRect])?

    public private(set) var cursorLocation: CGPoint?
    public private(set) var activeTextField: NSTextField?
    public private(set) var editingAnnotationID: UUID?

    private var isDraggingSelection = false
    private var isMarqueeSelecting = false
    private var dragOriginPoint: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var activeTouchIdentity: AnyObject?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        frame: NSRect,
        canvasState: AnnotationCanvasState,
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared
    ) {
        self.canvasState = canvasState
        self.settings = settings
        self.shortcutManager = shortcutManager
        super.init(frame: frame)
        self.wantsLayer = true
        self.allowedTouchTypes = [.indirect]

        canvasState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var acceptsFirstResponder: Bool { true }

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        if let window, let rects = exclusionScreenRectsProvider?(), !rects.isEmpty {
            let windowPoint = superview?.convert(point, to: nil) ?? point
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            if rects.contains(where: { $0.contains(screenPoint) }) {
                return nil
            }
        }
        return super.hitTest(point)
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override public func mouseMoved(with event: NSEvent) {
        cursorLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override public func mouseExited(with event: NSEvent) {
        cursorLocation = nil
        needsDisplay = true
    }

    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        cursorLocation = point
        commitActiveTextEditing()

        let flags = event.modifierFlags
        let isCommandDown = flags.contains(.command)
        let isShiftDown = flags.contains(.shift)
        let isOptionDown = flags.contains(.option)
        let isControlDown = flags.contains(.control)

        if isCommandDown {
            dragOriginPoint = point
            lastDragPoint = point
            if let hitID = canvasState.hitTestAnnotation(at: point) {
                if !canvasState.selectedIDs.contains(hitID) {
                    canvasState.toggleSelection(at: point, additive: isShiftDown)
                }
                isDraggingSelection = true
                isMarqueeSelecting = false
            } else {
                if !isShiftDown {
                    canvasState.selectedIDs.removeAll()
                }
                isDraggingSelection = false
                isMarqueeSelecting = true
                canvasState.selectionRectangle = CGRect(origin: point, size: .zero)
            }
            needsDisplay = true
            return
        }

        if settings.currentDrawMode == .text {
            beginInlineTextEditing(at: point)
            return
        }

        let effectiveAutoErase = isControlDown ? !settings.autoEraseEnabled : settings.autoEraseEnabled
        canvasState.beginStroke(
            at: point,
            mode: settings.currentDrawMode,
            color: settings.activeStrokeColor,
            gradient: settings.activeStrokeGradient,
            lineWeight: settings.lineWeight,
            isHighlighter: settings.currentDrawMode == .highlighter,
            isAutoErase: effectiveAutoErase,
            isShiftDown: isShiftDown,
            isOptionDown: isOptionDown
        )
        needsDisplay = true
    }

    override public func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        cursorLocation = point
        let flags = event.modifierFlags

        if isDraggingSelection {
            let delta = CGSize(width: point.x - lastDragPoint.x, height: point.y - lastDragPoint.y)
            lastDragPoint = point
            canvasState.moveSelectedAnnotations(by: delta)
            needsDisplay = true
            return
        }

        if isMarqueeSelecting {
            let rect = CGRect(
                x: min(dragOriginPoint.x, point.x),
                y: min(dragOriginPoint.y, point.y),
                width: abs(point.x - dragOriginPoint.x),
                height: abs(point.y - dragOriginPoint.y)
            )
            canvasState.selectAnnotations(in: rect)
            needsDisplay = true
            return
        }

        let hasNoDraft = canvasState.activeDraft == nil
        let isStrokeMode = !flags.contains(.command) && settings.currentDrawMode != .text
        if hasNoDraft && isStrokeMode {
            let effectiveAutoErase = flags.contains(.control) ? !settings.autoEraseEnabled : settings.autoEraseEnabled
            canvasState.beginStroke(
                at: point,
                mode: settings.currentDrawMode,
                color: settings.activeStrokeColor,
                gradient: settings.activeStrokeGradient,
                lineWeight: settings.lineWeight,
                isHighlighter: settings.currentDrawMode == .highlighter,
                isAutoErase: effectiveAutoErase,
                isShiftDown: flags.contains(.shift),
                isOptionDown: flags.contains(.option)
            )
        }

        canvasState.updateStroke(
            to: point,
            isShiftDown: flags.contains(.shift),
            isOptionDown: flags.contains(.option)
        )
        needsDisplay = true
    }

    override public func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        cursorLocation = point

        if isDraggingSelection || isMarqueeSelecting {
            isDraggingSelection = false
            isMarqueeSelecting = false
            canvasState.selectionRectangle = nil
            needsDisplay = true
            return
        }

        canvasState.updateStroke(
            to: point,
            isShiftDown: event.modifierFlags.contains(.shift),
            isOptionDown: event.modifierFlags.contains(.option)
        )
        canvasState.finishStroke()
        needsDisplay = true
    }

    override public func touchesBegan(with event: NSEvent) {
        guard settings.isTouchDrawActive else { return }
        let touches = event.touches(matching: .began, in: self)
        guard touches.count == 1, let touch = touches.first else { return }
        activeTouchIdentity = touch.identity
        let point = touchPoint(for: touch)
        cursorLocation = point
        canvasState.beginStroke(
            at: point,
            mode: settings.currentDrawMode == .text ? .freeHand : settings.currentDrawMode,
            color: settings.activeStrokeColor,
            gradient: settings.activeStrokeGradient,
            lineWeight: settings.lineWeight,
            isHighlighter: settings.currentDrawMode == .highlighter,
            isAutoErase: settings.autoEraseEnabled
        )
        needsDisplay = true
    }

    override public func touchesMoved(with event: NSEvent) {
        guard settings.isTouchDrawActive, let activeID = activeTouchIdentity else { return }
        let touches = event.touches(matching: .moved, in: self)
        guard let touch = touches.first(where: { $0.identity.isEqual(activeID) }) else { return }
        let point = touchPoint(for: touch)
        cursorLocation = point
        canvasState.updateStroke(to: point)
        needsDisplay = true
    }

    override public func touchesEnded(with event: NSEvent) {
        guard settings.isTouchDrawActive, let activeID = activeTouchIdentity else { return }
        let touches = event.touches(matching: .ended, in: self)
        guard touches.contains(where: { $0.identity.isEqual(activeID) }) else { return }
        activeTouchIdentity = nil
        canvasState.finishStroke()
        needsDisplay = true
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleKeyCommand(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override public func keyDown(with event: NSEvent) {
        if handleKeyCommand(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue) {
            return
        }
        super.keyDown(with: event)
    }

    @objc public func undo(_ sender: Any?) {
        canvasState.undo()
        needsDisplay = true
    }

    @objc public func redo(_ sender: Any?) {
        canvasState.redo()
        needsDisplay = true
    }

    @discardableResult
    public func handleKeyCommand(keyCode: UInt16, modifiers: UInt) -> Bool {
        if keyCode == 0x35 {
            if activeTextField != nil {
                cancelActiveTextEditing()
            } else if settings.isShowingShortcutsCheatsheet {
                settings.isShowingShortcutsCheatsheet = false
            } else {
                onRequestClose?()
            }
            return true
        }

        let normMods = modifiers & KeyBinding.relevantModifiersMask
        if normMods == KeyBinding.commandMask && keyCode == 0x0C {
            NSApp.terminate(nil)
            return true
        }
        if normMods == KeyBinding.commandMask && keyCode == 0x2B {
            onRequestOpenSettings?()
            return true
        }

        guard activeTextField == nil else { return false }

        if normMods == KeyBinding.commandMask && keyCode == 0x06 {
            canvasState.undo()
            needsDisplay = true
            return true
        }
        if (normMods == (KeyBinding.commandMask | KeyBinding.shiftMask) && keyCode == 0x06)
            || (normMods == KeyBinding.commandMask && keyCode == 0x10) {
            canvasState.redo()
            needsDisplay = true
            return true
        }
        if normMods == KeyBinding.commandMask && keyCode == 0x00 {
            canvasState.selectedIDs = Set(canvasState.annotations.map(\.id))
            needsDisplay = true
            return true
        }
        if normMods == KeyBinding.commandMask && keyCode == 0x01 {
            onRequestSaveScreenshot?()
            return true
        }
        if normMods == 0 && keyCode == 0x75 {
            canvasState.deleteSelectedOrClearAll()
            needsDisplay = true
            return true
        }
        if normMods == KeyBinding.shiftMask && keyCode == 0x2C {
            settings.isShowingShortcutsCheatsheet.toggle()
            needsDisplay = true
            return true
        }

        guard let matched = shortcutManager.matchLocalAnnotateCommand(keyCode: keyCode, modifiers: modifiers) else {
            return false
        }

        switch matched.command {
        case .firstFavColor: settings.selectFavoriteColor(index: 0)
        case .secondFavColor: settings.selectFavoriteColor(index: 1)
        case .thirdFavColor: settings.selectFavoriteColor(index: 2)
        case .fourthFavColor: settings.selectFavoriteColor(index: 3)
        case .fifthFavColor: settings.selectFavoriteColor(index: 4)
        case .randomColors:
            settings.enableGradients = true
            settings.selectRandomColors()
        case .freeHand: settings.selectOrToggleDrawMode(.freeHand)
        case .arrow: settings.selectOrToggleDrawMode(.arrow)
        case .rectangle: settings.selectOrToggleDrawMode(.rectangle)
        case .circle: settings.selectOrToggleDrawMode(.circle)
        case .text: settings.selectOrToggleDrawMode(.text)
        case .highlighter: settings.selectOrToggleDrawMode(.highlighter)
        case .clearAnnotate: canvasState.deleteSelectedOrClearAll()
        case .decreaseLineWeight:
            settings.decreaseLineWeight()
            onLineWeightChanged?(settings.lineWeight)
        case .increaseLineWeight:
            settings.increaseLineWeight()
            onLineWeightChanged?(settings.lineWeight)
        case .setLineWeight:
            if let digit = matched.lineWeightDigit {
                settings.setLineWeightFromDigit(digit)
                onLineWeightChanged?(settings.lineWeight)
            }
        case .touchDraw:
            settings.isTouchDrawActive.toggle()
        case .annotateWhiteboard:
            settings.isWhiteboardActive.toggle()
        case .saveScreenshot:
            onRequestSaveScreenshot?()
        case .copyScreenshot:
            if !canvasState.selectedIDs.isEmpty {
                canvasState.copySelectedAnnotations()
            } else {
                onRequestCopyScreenshot?()
            }
        case .pasteAnnotations:
            canvasState.pasteAnnotations()
        case .annotateShortcuts:
            settings.isShowingShortcutsCheatsheet.toggle()
        default:
            return false
        }

        needsDisplay = true
        return true
    }

    public func beginInlineTextEditing(at point: CGPoint, existingID: UUID? = nil) {
        commitActiveTextEditing()
        editingAnnotationID = existingID

        let field = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 260, height: max(36, CGFloat(settings.annotateFontSize * 1.45))))
        field.isBordered = true
        field.isBezeled = true
        field.drawsBackground = true
        field.backgroundColor = NSColor.black.withAlphaComponent(0.45)
        field.textColor = settings.activeStrokeColor.nsColor
        field.font = NSFont(name: settings.annotateFont.fontName, size: CGFloat(settings.annotateFontSize))
            ?? NSFont.systemFont(ofSize: CGFloat(settings.annotateFontSize), weight: .semibold)
        if settings.annotateTextPlaceholder {
            field.placeholderString = "Type something..."
        }
        field.delegate = self
        field.target = self
        field.action = #selector(textFieldCommitted(_:))
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
    }

    public func commitActiveTextEditing() {
        guard let field = activeTextField else { return }
        let value = field.stringValue
        let origin = field.frame.origin
        let editID = editingAnnotationID
        field.removeFromSuperview()
        activeTextField = nil
        editingAnnotationID = nil

        canvasState.addOrUpdateTextAnnotation(
            id: editID,
            at: origin,
            text: value,
            color: settings.activeStrokeColor,
            fontName: settings.annotateFont.fontName,
            fontSize: settings.annotateFontSize,
            isAutoErase: settings.autoEraseEnabled
        )
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    public func cancelActiveTextEditing() {
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        editingAnnotationID = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    @objc private func textFieldCommitted(_ sender: NSTextField) {
        commitActiveTextEditing()
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelActiveTextEditing()
            return true
        }
        return false
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        if settings.isWhiteboardActive {
            context.setFillColor(
                settings.annotateWhiteboardColor.nsColor
                    .withAlphaComponent(CGFloat(settings.whiteboardOpacity))
                    .cgColor
            )
            context.fill(bounds)
        } else if settings.dimScreenOnAnnotate {
            context.setFillColor(NSColor.black.withAlphaComponent(CGFloat(settings.dimScreenOpacity)).cgColor)
            context.fill(bounds)
        }

        for item in canvasState.annotations {
            drawAnnotation(item, in: context, isSelected: canvasState.selectedIDs.contains(item.id))
        }
        if let draft = canvasState.activeDraft {
            drawAnnotation(draft, in: context, isSelected: false)
        }

        if let marquee = canvasState.selectionRectangle {
            context.saveGState()
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.14).cgColor)
            context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.75).cgColor)
            context.setLineWidth(1.5)
            context.fill(marquee)
            context.stroke(marquee)
            context.restoreGState()
        }

        if settings.annotateToolIndicator, let cursor = cursorLocation {
            drawToolIndicator(at: cursor, in: context)
        }
    }

    private func drawAnnotation(_ item: AnnotationItem, in context: CGContext, isSelected: Bool) {
        context.saveGState()
        if item.isHighlighter {
            context.setBlendMode(.multiply)
        }

        let path = buildCGPath(for: item)
        let color = item.strokeColor.nsColor

        switch item.mode {
        case .text:
            let font = NSFont(name: item.fontName, size: CGFloat(item.fontSize))
                ?? NSFont.systemFont(ofSize: CGFloat(item.fontSize), weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            (item.text as NSString).draw(at: item.startPoint, withAttributes: attrs)
        case .arrow:
            if let gradient = item.gradientPair {
                context.addPath(path)
                context.clip()
                drawLinearGradient(gradient, from: item.startPoint, to: item.endPoint, in: context)
            } else {
                context.addPath(path)
                context.setFillColor(color.cgColor)
                context.fillPath()
            }
        case .rectangle, .circle:
            if item.isFilled {
                context.addPath(path)
                context.setFillColor(color.withAlphaComponent(0.28).cgColor)
                context.fillPath()
            }
            strokePath(path, item: item, color: color, in: context)
        case .freeHand, .highlighter:
            strokePath(path, item: item, color: color, in: context)
        }

        if isSelected {
            let selectionBox = item.boundingRect.insetBy(dx: -4, dy: -4)
            context.setStrokeColor(NSColor.systemCyan.cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.stroke(selectionBox)
        }

        context.restoreGState()
    }

    private func strokePath(_ path: CGPath, item: AnnotationItem, color: NSColor, in context: CGContext) {
        context.setLineWidth(CGFloat(item.lineWeight))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)

        if let gradient = item.gradientPair {
            context.replacePathWithStrokedPath()
            context.clip()
            let box = item.boundingRect
            drawLinearGradient(
                gradient,
                from: CGPoint(x: box.minX, y: box.minY),
                to: CGPoint(x: box.maxX, y: box.maxY),
                in: context
            )
        } else {
            context.setStrokeColor(color.cgColor)
            context.strokePath()
        }
    }

    private func drawLinearGradient(
        _ pair: GradientPair,
        from start: CGPoint,
        to end: CGPoint,
        in context: CGContext
    ) {
        let colors = [pair.startColor.nsColor.cgColor, pair.endColor.nsColor.cgColor] as CFArray
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cgGradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) else {
            return
        }
        context.drawLinearGradient(cgGradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private func buildCGPath(for item: AnnotationItem) -> CGPath {
        let path = CGMutablePath()
        switch item.mode {
        case .freeHand, .highlighter:
            guard let first = item.points.first else { return path }
            path.move(to: first)
            for pt in item.points.dropFirst() {
                path.addLine(to: pt)
            }
        case .arrow:
            let vertices = item.arrowPolygonPoints()
            if let first = vertices.first {
                path.move(to: first)
                for pt in vertices.dropFirst() {
                    path.addLine(to: pt)
                }
                path.closeSubpath()
            }
        case .rectangle:
            path.addRect(item.boundingRect)
        case .circle:
            path.addEllipse(in: item.boundingRect)
        case .text:
            path.addRect(item.boundingRect)
        }
        return path
    }

    private func drawToolIndicator(at cursor: CGPoint, in context: CGContext) {
        context.saveGState()
        let badgeCenter = CGPoint(x: cursor.x + 14, y: cursor.y - 14)
        let radius = max(4.0, min(12.0, CGFloat(settings.lineWeight * 0.5)))
        let badgeRect = CGRect(
            x: badgeCenter.x - radius,
            y: badgeCenter.y - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
        context.setFillColor(settings.activeStrokeColor.nsColor.cgColor)
        context.fillEllipse(in: badgeRect)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: badgeRect)
        context.restoreGState()
    }

    private func touchPoint(for touch: NSTouch) -> CGPoint {
        let normalized = touch.normalizedPosition
        return CGPoint(
            x: bounds.origin.x + normalized.x * bounds.size.width,
            y: bounds.origin.y + normalized.y * bounds.size.height
        )
    }
}

public final class AnnotateOverlayController {
    public let settings: AppSettings
    public let shortcutManager: ShortcutManager
    public let canvasState: AnnotationCanvasState
    public let toastController: ToastWindowController

    public private(set) var panel: AnnotatePanel?
    public private(set) var canvasView: AnnotateCanvasView?
    public private(set) var controlsPanel: FloatingControlPanel?
    public private(set) var shortcutsPanel: FloatingControlPanel?
    public var onRequestOpenSettings: (() -> Void)?

    private var autoEraseTimer: Timer?
    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []
    private static let savedSessionKey = "presentify.savedAnnotationSession"

    public init(
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared,
        canvasState: AnnotationCanvasState = AnnotationCanvasState()
    ) {
        self.settings = settings
        self.shortcutManager = shortcutManager
        self.canvasState = canvasState
        self.toastController = ToastWindowController(settings: settings)

        if settings.annotateSaveSession,
           let savedData = settings.defaults.data(forKey: Self.savedSessionKey) {
            canvasState.importSessionData(savedData)
        }

        bindSettings()
    }

    deinit {
        stopTimersAndMonitors()
    }

    public func toggleAnnotation() {
        if settings.isAnnotating {
            hideAnnotation()
        } else {
            showAnnotation()
        }
    }

    public func toggleAnnotateControls() {
        if !settings.isAnnotating {
            settings.showAnnotateControls = true
            showAnnotation()
        } else {
            settings.showAnnotateControls.toggle()
            updateAuxiliaryPanels()
        }
    }

    public func showAnnotation() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        if panel == nil {
            let newPanel = AnnotatePanel(contentRect: screenFrame)
            let view = AnnotateCanvasView(
                frame: NSRect(origin: .zero, size: screenFrame.size),
                canvasState: canvasState,
                settings: settings,
                shortcutManager: shortcutManager
            )
            view.onRequestSaveScreenshot = { [weak self] in self?.saveScreenshot() }
            view.onRequestCopyScreenshot = { [weak self] in self?.copyScreenshot() }
            view.onRequestClose = { [weak self] in self?.hideAnnotation() }
            view.onRequestOpenSettings = { [weak self] in self?.onRequestOpenSettings?() }
            view.onLineWeightChanged = { [weak self] weight in
                self?.toastController.showToast(.lineWeight, message: "Line Weight: \(Int(weight)) pt")
            }
            view.exclusionScreenRectsProvider = { [weak self] in
                self?.visibleAuxiliaryPanelRects() ?? []
            }
            newPanel.contentView = view
            self.panel = newPanel
            self.canvasView = view
        }

        panel?.setFrame(screenFrame, display: true)
        canvasView?.frame = NSRect(origin: .zero, size: screenFrame.size)
        panel?.updateBackground(from: settings)
        updateInteractivePassThrough(modifierFlags: NSEvent.modifierFlags)
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(canvasView)

        settings.isAnnotating = true
        updateAuxiliaryPanels()
        startTimersAndMonitors()

        if settings.annotateInteractiveMode {
            toastController.showToast(
                .interactiveMode,
                message: "Interactive Mode active: Hold \(settings.interactiveModeKey.title) to draw"
            )
        }
    }

    public func hideAnnotation() {
        canvasView?.commitActiveTextEditing()
        if settings.annotateSaveSession, let data = canvasState.exportSessionData() {
            settings.defaults.set(data, forKey: Self.savedSessionKey)
        } else if !settings.annotateSaveSession {
            canvasState.clearAll()
        }

        stopTimersAndMonitors()
        CustomColorPanelBridge.shared.close()
        controlsPanel?.orderOut(nil)
        shortcutsPanel?.orderOut(nil)
        panel?.orderOut(nil)
        toastController.dismiss()
        settings.isAnnotating = false
    }

    @discardableResult
    public func saveScreenshot() -> URL? {
        guard let view = canvasView else { return nil }
        return Screenshotter.saveViewScreenshot(view, directoryPath: settings.screenshotSaveDirectoryPath)
    }

    @discardableResult
    public func copyScreenshot() -> Bool {
        guard let view = canvasView else { return false }
        return Screenshotter.copyViewScreenshotToPasteboard(view)
    }

    public func updateInteractivePassThrough(modifierFlags: NSEvent.ModifierFlags) {
        guard let panel else { return }
        guard settings.annotateInteractiveMode else {
            panel.ignoresMouseEvents = false
            return
        }
        let isHoldKeyActive: Bool
        switch settings.interactiveModeKey {
        case .fn:
            isHoldKeyActive = modifierFlags.contains(.function)
        case .capsLock:
            isHoldKeyActive = modifierFlags.contains(.capsLock)
        }
        panel.ignoresMouseEvents = !isHoldKeyActive
    }

    private func visibleAuxiliaryPanelRects() -> [NSRect] {
        var rects: [NSRect] = []
        if settings.showAnnotateControls, let controlsPanel, controlsPanel.isVisible {
            rects.append(controlsPanel.frame)
        }
        if settings.isShowingShortcutsCheatsheet, let shortcutsPanel, shortcutsPanel.isVisible {
            rects.append(shortcutsPanel.frame)
        }
        if NSColorPanel.sharedColorPanelExists && NSColorPanel.shared.isVisible {
            rects.append(NSColorPanel.shared.frame)
        }
        return rects
    }

    private func bindSettings() {
        settings.$currentDrawMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.settings.isAnnotating else { return }
                self.canvasView?.commitActiveTextEditing()
                self.panel?.makeKey()
                self.panel?.makeFirstResponder(self.canvasView)
                self.canvasView?.needsDisplay = true
            }
            .store(in: &cancellables)

        settings.$whiteboardEnabled
            .combineLatest(settings.$whiteboardColor, settings.$dimScreenOnAnnotate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                guard let self else { return }
                self.panel?.updateBackground(from: self.settings)
                self.canvasView?.needsDisplay = true
            }
            .store(in: &cancellables)

        settings.$touchDrawEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self, enabled, self.settings.isAnnotating else { return }
                self.toastController.showToast(.touchDraw, message: "Touch Draw enabled: Draw with 1 finger on trackpad")
            }
            .store(in: &cancellables)

        settings.$selectedColorIndex
            .combineLatest(settings.$favColors, settings.$useRandomColors, settings.$enableGradients)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                guard let self, self.settings.isAnnotating else { return }
                self.canvasView?.activeTextField?.textColor = self.settings.activeStrokeColor.nsColor
                self.canvasView?.needsDisplay = true
            }
            .store(in: &cancellables)

        settings.$isShowingShortcutsCheatsheet
            .combineLatest(settings.$annotateControlsVertical)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateAuxiliaryPanels() }
            .store(in: &cancellables)
    }

    private func updateAuxiliaryPanels() {
        guard settings.isAnnotating else {
            controlsPanel?.orderOut(nil)
            shortcutsPanel?.orderOut(nil)
            return
        }

        if settings.showAnnotateControls {
            if controlsPanel == nil {
                let toolbarView = AnnotateControlsView(
                    settings: settings,
                    onUndo: { [weak self] in self?.canvasState.undo() },
                    onRedo: { [weak self] in self?.canvasState.redo() },
                    onSaveScreenshot: { [weak self] in _ = self?.saveScreenshot() },
                    onClear: { [weak self] in self?.canvasState.clearAll() },
                    onToggleShortcuts: { [weak self] in self?.settings.isShowingShortcutsCheatsheet.toggle() },
                    onClose: { [weak self] in self?.hideAnnotation() }
                )
                let hosting = FirstMouseHostingView(rootView: toolbarView)
                let fitting = hosting.fittingSize
                let width = fitting.width > 0 ? fitting.width : 720
                let height = fitting.height > 0 ? fitting.height : 52
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
                let cPanel = FloatingControlPanel(contentRect: hosting.frame)
                cPanel.onKeyDown = { [weak self] event in
                    self?.canvasView?.handleKeyCommand(
                        keyCode: event.keyCode,
                        modifiers: event.modifierFlags.rawValue
                    ) ?? false
                }
                cPanel.contentView = hosting
                if let visible = NSScreen.main?.visibleFrame {
                    cPanel.setFrameOrigin(NSPoint(x: visible.midX - width * 0.5, y: visible.minY + 36))
                }
                controlsPanel = cPanel
            } else if let cPanel = controlsPanel, let hosting = cPanel.contentView {
                let fitting = hosting.fittingSize
                let hasValidFittingSize = fitting.width > 0 && fitting.height > 0
                if hasValidFittingSize && cPanel.frame.size != fitting {
                    cPanel.setContentSize(fitting)
                }
            }
            controlsPanel?.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
            controlsPanel?.orderFrontRegardless()
        } else {
            controlsPanel?.orderOut(nil)
        }

        if settings.isShowingShortcutsCheatsheet {
            if shortcutsPanel == nil {
                let hud = AnnotateShortcutsView(
                    shortcutManager: shortcutManager,
                    onClose: { [weak self] in self?.settings.isShowingShortcutsCheatsheet = false }
                )
                let hosting = FirstMouseHostingView(rootView: hud)
                let fitting = hosting.fittingSize
                let width = fitting.width > 0 ? fitting.width : 560
                let height = fitting.height > 0 ? fitting.height : 440
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
                let sPanel = FloatingControlPanel(contentRect: hosting.frame)
                sPanel.onKeyDown = { [weak self] event in
                    self?.canvasView?.handleKeyCommand(
                        keyCode: event.keyCode,
                        modifiers: event.modifierFlags.rawValue
                    ) ?? false
                }
                sPanel.contentView = hosting
                if let visible = NSScreen.main?.visibleFrame {
                    sPanel.setFrameOrigin(NSPoint(x: visible.midX - width * 0.5, y: visible.midY - height * 0.5))
                }
                shortcutsPanel = sPanel
            }
            shortcutsPanel?.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
            shortcutsPanel?.orderFrontRegardless()
        } else {
            shortcutsPanel?.orderOut(nil)
        }
    }

    private func startTimersAndMonitors() {
        stopTimersAndMonitors()
        autoEraseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.canvasState.pruneExpiredAnnotations(delay: self.settings.autoEraseDelay)
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateInteractivePassThrough(modifierFlags: event.modifierFlags)
            return event
        }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.settings.isAnnotating else { return event }
            if self.canvasView?.activeTextField != nil, event.keyCode != 0x35 {
                return event
            }
            if self.canvasView?.handleKeyCommand(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.rawValue
            ) == true {
                return nil
            }
            return event
        }
    }

    private func stopTimersAndMonitors() {
        autoEraseTimer?.invalidate()
        autoEraseTimer = nil
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }
}
