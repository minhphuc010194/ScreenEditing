import AppKit
import SwiftUI

public final class FloatingControlPanel: NSPanel {
    public var onKeyDown: ((NSEvent) -> Bool)?
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var isDraggingPanel = false

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.becomesKeyOnlyIfNeeded = true
        self.isMovableByWindowBackground = false
        self.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }

    override public func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartWindowOrigin = frame.origin
            isDraggingPanel = false
            super.sendEvent(event)
        case .leftMouseDragged:
            if let startMouse = dragStartMouseLocation, let startOrigin = dragStartWindowOrigin {
                let currentMouse = NSEvent.mouseLocation
                let dx = currentMouse.x - startMouse.x
                let dy = currentMouse.y - startMouse.y
                if !isDraggingPanel && hypot(dx, dy) >= 2.5 {
                    isDraggingPanel = true
                }
                if isDraggingPanel {
                    setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
                    return
                }
            }
            super.sendEvent(event)
        case .leftMouseUp:
            let wasDragging = isDraggingPanel
            dragStartMouseLocation = nil
            dragStartWindowOrigin = nil
            isDraggingPanel = false
            if wasDragging {
                if let cancelUp = NSEvent.mouseEvent(
                    with: .leftMouseUp,
                    location: NSPoint(x: -100, y: -100),
                    modifierFlags: event.modifierFlags,
                    timestamp: event.timestamp,
                    windowNumber: windowNumber,
                    context: nil,
                    eventNumber: event.eventNumber,
                    clickCount: 0,
                    pressure: 0
                ) {
                    super.sendEvent(cancelUp)
                }
                return
            }
            super.sendEvent(event)
        default:
            super.sendEvent(event)
        }
    }

    override public func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}

public final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

public enum ToastKind: String, CaseIterable, Sendable {
    case interactiveMode
    case highlightMode
    case touchDraw
    case lineWeight
}

public struct ToastBannerView: View {
    public let message: String
    public let onDontShowAgain: () -> Void
    public let onClose: () -> Void

    public init(message: String, onDontShowAgain: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.message = message
        self.onDontShowAgain = onDontShowAgain
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Button("Don't show again") {
                onDontShowAgain()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .contentShape(Rectangle())
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

public final class ToastWindowController {
    public let settings: AppSettings
    public private(set) var panel: FloatingControlPanel?
    public private(set) var currentToast: ToastKind?
    public private(set) var currentMessage: String = ""
    private var dismissTimer: Timer?

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    public func isEnabled(for kind: ToastKind) -> Bool {
        switch kind {
        case .interactiveMode: return settings.toastInteractiveMode
        case .highlightMode: return settings.toastHighlightMode
        case .touchDraw: return settings.toastTouchDraw
        case .lineWeight: return settings.toastLineWeight
        }
    }

    public func showToast(_ kind: ToastKind, message: String, autoDismissAfter: TimeInterval = 3.0) {
        guard isEnabled(for: kind) else { return }
        dismissTimer?.invalidate()
        currentToast = kind
        currentMessage = message

        let contentView = ToastBannerView(
            message: message,
            onDontShowAgain: { [weak self] in self?.dismissAndDontShowAgain() },
            onClose: { [weak self] in self?.dismiss() }
        )

        let hosting = FirstMouseHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 460, height: 48)

        let toastPanel: FloatingControlPanel
        if let existing = panel {
            toastPanel = existing
        } else {
            toastPanel = FloatingControlPanel(contentRect: hosting.frame)
            panel = toastPanel
        }

        toastPanel.contentView = hosting
        if let screenFrame = NSScreen.main?.visibleFrame {
            let originX = screenFrame.midX - hosting.frame.width * 0.5
            let originY = screenFrame.maxY - 90
            toastPanel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }
        toastPanel.orderFrontRegardless()

        if autoDismissAfter > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissAfter, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    public func dismissAndDontShowAgain() {
        if let kind = currentToast {
            switch kind {
            case .interactiveMode: settings.toastInteractiveMode = false
            case .highlightMode: settings.toastHighlightMode = false
            case .touchDraw: settings.toastTouchDraw = false
            case .lineWeight: settings.toastLineWeight = false
            }
        }
        dismiss()
    }

    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentToast = nil
        currentMessage = ""
        panel?.orderOut(nil)
    }
}

public struct AnnotateControlsView: View {
    @ObservedObject public var settings: AppSettings
    public let canvasState: AnnotationCanvasState?
    public var onUndo: () -> Void
    public var onRedo: () -> Void
    public var onSaveScreenshot: () -> Void
    public var onClear: () -> Void
    public var onToggleShortcuts: () -> Void
    public var onClose: () -> Void
    public var onDragToolbar: (CGSize) -> Void

    public init(
        settings: AppSettings,
        canvasState: AnnotationCanvasState? = nil,
        onUndo: @escaping () -> Void = {},
        onRedo: @escaping () -> Void = {},
        onSaveScreenshot: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {},
        onToggleShortcuts: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        onDragToolbar: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.settings = settings
        self.canvasState = canvasState
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onSaveScreenshot = onSaveScreenshot
        self.onClear = onClear
        self.onToggleShortcuts = onToggleShortcuts
        self.onClose = onClose
        self.onDragToolbar = onDragToolbar
    }

    public var body: some View {
        let layout = settings.annotateControlsVertical
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        layout {
            dragHandleSection
            Divider().frame(height: settings.annotateControlsVertical ? 1 : 22)
            colorPaletteSection
            Divider().frame(height: settings.annotateControlsVertical ? 1 : 22)
            drawingToolsSection
            Divider().frame(height: settings.annotateControlsVertical ? 1 : 22)
            lineWeightSection
            Divider().frame(height: settings.annotateControlsVertical ? 1 : 22)
            modeAndActionButtonsSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private var dragHandleSection: some View {
        HStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.75))
                            .frame(width: 3.5, height: 3.5)
                    }
                }
            }
        }
        .frame(width: 18, height: 28)
        .contentShape(Rectangle())
        .help("Drag Toolbar")
    }

    private var colorPaletteSection: some View {
        HStack(spacing: 6) {
            ForEach(Array(settings.favColors.prefix(5).enumerated()), id: \.offset) { index, color in
                Button {
                    settings.selectFavoriteColor(index: index)
                } label: {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    (!settings.useRandomColors && settings.selectedColorIndex == index) ? Color.white : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .help("Favorite Color \(index + 1) (\(index + 1))")
            }

            Button {
                settings.enableGradients = true
                settings.selectRandomColors()
            } label: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                settings.activeGradient.startColor.swiftUIColor,
                                settings.activeGradient.endColor.swiftUIColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(settings.useRandomColors ? Color.white : Color.clear, lineWidth: 2)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .help("Random Colors / Gradient (6)")
        }
    }

    private var drawingToolsSection: some View {
        HStack(spacing: 4) {
            ForEach(DrawMode.allCases) { mode in
                Button {
                    settings.selectOrToggleDrawMode(mode)
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(
                            settings.currentDrawMode == mode ? Color.accentColor.opacity(0.28) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help(mode.title)
            }
        }
    }

    private var lineWeightSection: some View {
        HStack(spacing: 4) {
            Button {
                settings.decreaseLineWeight()
            } label: {
                Image(systemName: "minus.circle")
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Decrease Line Weight ([)")

            Text("\(Int(settings.lineWeight))pt")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(width: 34)

            Button {
                settings.increaseLineWeight()
            } label: {
                Image(systemName: "plus.circle")
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Increase Line Weight (])")
        }
    }

    private var modeAndActionButtonsSection: some View {
        HStack(spacing: 6) {
            toolbarToggle(
                icon: "rectangle.inset.filled",
                isActive: settings.isWhiteboardActive,
                tooltip: "Whiteboard (W)"
            ) {
                settings.isWhiteboardActive.toggle()
            }

            toolbarToggle(
                icon: "timer",
                isActive: settings.autoEraseEnabled,
                tooltip: "Auto Erase"
            ) {
                settings.autoEraseEnabled.toggle()
            }

            toolbarToggle(
                icon: "hand.draw",
                isActive: settings.isTouchDrawActive,
                tooltip: "Touch Draw (D)"
            ) {
                settings.isTouchDrawActive.toggle()
            }

            Button {
                if let canvasState {
                    canvasState.undo()
                } else {
                    onUndo()
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Undo (⌘Z)")

            Button {
                if let canvasState {
                    canvasState.redo()
                } else {
                    onRedo()
                }
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Redo (⌘⇧Z)")

            Button(action: onSaveScreenshot) {
                Image(systemName: "camera")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Save Screenshot (S)")

            Button(action: onClear) {
                Image(systemName: "trash")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Clear Annotations (Delete)")

            toolbarToggle(
                icon: "keyboard",
                isActive: settings.isShowingShortcutsCheatsheet,
                tooltip: "Shortcuts (/)"
            ) {
                onToggleShortcuts()
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Close Annotate (Esc)")
        }
    }

    private func toolbarToggle(
        icon: String,
        isActive: Bool,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(
                    isActive ? Color.purple.opacity(0.32) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(tooltip)
    }
}

public struct AnnotateShortcutsView: View {
    @ObservedObject public var shortcutManager: ShortcutManager
    public var onClose: () -> Void

    public static let modifierTips: [(symbol: String, description: String)] = [
        ("⇧ Shift", "Hold while drawing to constrain straight lines (45°), squares, or circles."),
        ("⌥ Option", "Hold while drawing a rectangle or circle to fill the shape."),
        ("⌃ Control", "Hold while drawing to invert Auto Erase for the current stroke."),
        ("⌘ Command", "Hold to click or marquee-select annotations, drag to move, or Delete to remove."),
        ("Esc", "Exit active text field or close the annotation overlay.")
    ]

    public init(shortcutManager: ShortcutManager = .shared, onClose: @escaping () -> Void = {}) {
        self.shortcutManager = shortcutManager
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Annotation Shortcuts & Tips", systemImage: "keyboard")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                ForEach(ShortcutCategory.annotate.commands) { command in
                    HStack {
                        Text(command.title)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(shortcutManager.binding(for: command).displayString)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Divider()

            Text("Power-User Modifiers")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Self.modifierTips, id: \.symbol) { tip in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(tip.symbol)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(width: 82, alignment: .leading)
                        Text(tip.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 560)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
