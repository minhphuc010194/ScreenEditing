import AppKit
import SwiftUI

public struct PresentifyMenuView: View {
    @ObservedObject public var settings: AppSettings
    @ObservedObject public var shortcutManager: ShortcutManager
    public var onToggleAnnotate: () -> Void
    public var onToggleAnnotateControls: () -> Void
    public var onToggleHighlight: () -> Void
    public var onToggleSpotlight: () -> Void
    public var onToggleZoom: () -> Void
    public var onOpenSettings: () -> Void
    public var onOpenWelcomeTour: () -> Void
    public var onCheckForUpdates: () -> Void
    public var onQuit: () -> Void
    @State private var hoveredRowTitle: String?

    public init(
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared,
        onToggleAnnotate: @escaping () -> Void = {},
        onToggleAnnotateControls: @escaping () -> Void = {},
        onToggleHighlight: @escaping () -> Void = {},
        onToggleSpotlight: @escaping () -> Void = {},
        onToggleZoom: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onOpenWelcomeTour: @escaping () -> Void = {},
        onCheckForUpdates: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.settings = settings
        self.shortcutManager = shortcutManager
        self.onToggleAnnotate = onToggleAnnotate
        self.onToggleAnnotateControls = onToggleAnnotateControls
        self.onToggleHighlight = onToggleHighlight
        self.onToggleSpotlight = onToggleSpotlight
        self.onToggleZoom = onToggleZoom
        self.onOpenSettings = onOpenSettings
        self.onOpenWelcomeTour = onOpenWelcomeTour
        self.onCheckForUpdates = onCheckForUpdates
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            menuRow(
                title: settings.isAnnotating ? "Stop Annotating" : "Annotate Screen",
                icon: "pencil.tip.crop.circle",
                shortcut: shortcutManager.binding(for: .toggleAnnotateScreen).displayString,
                isActive: settings.isAnnotating,
                action: onToggleAnnotate
            )

            menuRow(
                title: "Annotate Controls",
                icon: "slider.horizontal.below.rectangle",
                shortcut: shortcutManager.binding(for: .toggleAnnotateControls).displayString,
                isActive: settings.isAnnotating && settings.showAnnotateControls,
                action: onToggleAnnotateControls
            )

            Divider()

            menuRow(
                title: "Highlight Cursor",
                icon: "cursorarrow.rays",
                shortcut: shortcutManager.binding(for: .toggleHighlightCursor).displayString,
                isActive: settings.isHighlightingCursor,
                action: onToggleHighlight
            )

            menuRow(
                title: "Spotlight Cursor",
                icon: "flashlight.on.fill",
                shortcut: shortcutManager.binding(for: .toggleSpotlightCursor).displayString,
                isActive: settings.isSpotlightingCursor,
                action: onToggleSpotlight
            )

            menuRow(
                title: "Zoom Cursor",
                icon: "plus.magnifyingglass",
                shortcut: shortcutManager.binding(for: .toggleZoomCursor).displayString,
                isActive: settings.isZoomingCursor,
                action: onToggleZoom
            )

            Divider()

            menuRow(
                title: "Welcome Tour...",
                icon: "sparkles",
                shortcut: "",
                isActive: false,
                action: onOpenWelcomeTour
            )

            menuRow(
                title: "Check for Updates...",
                icon: "arrow.triangle.2.circlepath",
                shortcut: "",
                isActive: false,
                action: onCheckForUpdates
            )

            menuRow(
                title: "Settings...",
                icon: "gearshape",
                shortcut: "⌘,",
                isActive: false,
                action: onOpenSettings
            )

            Divider()

            menuRow(
                title: "Quit ScreenEditing",
                icon: "power",
                shortcut: "⌘Q",
                isActive: false,
                action: onQuit
            )
        }
        .padding(10)
        .frame(width: 260)
        .tint(SettingsView.themeBlue)
    }

    private func menuRow(
        title: String,
        icon: String,
        shortcut: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredRowTitle == title
        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isActive ? Color.white : SettingsView.themeBlue)
                    .background(
                        isActive ? Color.white.opacity(0.22) : SettingsView.themeBlue.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? Color.white : Color.primary)
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(isActive ? Color.white : SettingsView.themeBlue)
                        .background(
                            isActive ? Color.white.opacity(0.22) : SettingsView.themeBlue.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? SettingsView.themeBlue
                    : (isHovered ? SettingsView.themeBlue.opacity(0.10) : Color.clear),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredRowTitle = hovering ? title : (hoveredRowTitle == title ? nil : hoveredRowTitle)
        }
    }
}

public final class PresentifyDockMenuController: NSObject {
    public let settings: AppSettings
    public var onToggleAnnotate: (() -> Void)?
    public var onToggleHighlight: (() -> Void)?
    public var onToggleSpotlight: (() -> Void)?
    public var onToggleZoom: (() -> Void)?
    public var onOpenSettings: (() -> Void)?

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    public func buildDockMenu() -> NSMenu {
        let menu = NSMenu(title: "ScreenEditing")

        let annotateItem = NSMenuItem(
            title: settings.isAnnotating ? "Stop Annotating" : "Annotate Screen",
            action: #selector(handleAnnotate),
            keyEquivalent: ""
        )
        annotateItem.target = self
        annotateItem.state = settings.isAnnotating ? .on : .off
        menu.addItem(annotateItem)

        let highlightItem = NSMenuItem(
            title: "Highlight Cursor",
            action: #selector(handleHighlight),
            keyEquivalent: ""
        )
        highlightItem.target = self
        highlightItem.state = settings.isHighlightingCursor ? .on : .off
        menu.addItem(highlightItem)

        let spotlightItem = NSMenuItem(
            title: "Spotlight Cursor",
            action: #selector(handleSpotlight),
            keyEquivalent: ""
        )
        spotlightItem.target = self
        spotlightItem.state = settings.isSpotlightingCursor ? .on : .off
        menu.addItem(spotlightItem)

        let zoomItem = NSMenuItem(
            title: "Zoom Cursor",
            action: #selector(handleZoom),
            keyEquivalent: ""
        )
        zoomItem.target = self
        zoomItem.state = settings.isZoomingCursor ? .on : .off
        menu.addItem(zoomItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(handleSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        return menu
    }

    @objc private func handleAnnotate() { onToggleAnnotate?() }
    @objc private func handleHighlight() { onToggleHighlight?() }
    @objc private func handleSpotlight() { onToggleSpotlight?() }
    @objc private func handleZoom() { onToggleZoom?() }
    @objc private func handleSettings() { onOpenSettings?() }
}

public struct WelcomeTourStep: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let subtitle: String
    public let systemImage: String
}

public struct WelcomeTourView: View {
    public static let pages: [WelcomeTourStep] = [
        WelcomeTourStep(
            id: 0,
            title: "Welcome to ScreenEditing",
            subtitle: "Elevate your screen sharing, online classes, and video presentations with instant annotations and cursor effects.",
            systemImage: "tv.and.mediabox"
        ),
        WelcomeTourStep(
            id: 1,
            title: "Annotate Anywhere",
            subtitle: "Draw freehand strokes, arrows, rectangles, circles, text, and highlights over any app or full-screen keynote.",
            systemImage: "pencil.tip.crop.circle"
        ),
        WelcomeTourStep(
            id: 2,
            title: "Whiteboard & Auto-Erase",
            subtitle: "Switch to a custom whiteboard canvas with W, or enable Auto-Erase so your ink fades out automatically.",
            systemImage: "rectangle.inset.filled"
        ),
        WelcomeTourStep(
            id: 3,
            title: "Highlight & Spotlight Cursor",
            subtitle: "Keep your audience focused on your pointer with customizable shapes, click animations, and screen spotlight.",
            systemImage: "cursorarrow.rays"
        ),
        WelcomeTourStep(
            id: 4,
            title: "Magnify with Cursor Zoom",
            subtitle: "Zoom into fine UI details smoothly with ScreenCaptureKit magnification and full-screen zoom.",
            systemImage: "plus.magnifyingglass"
        ),
        WelcomeTourStep(
            id: 5,
            title: "Global Shortcuts & Modifiers",
            subtitle: "Press ⌃⌥A to annotate, ⌃⌥H to highlight, and hold ⇧, ⌥, ⌃, or ⌘ while drawing for pro controls.",
            systemImage: "command"
        )
    ]

    @ObservedObject public var settings: AppSettings
    @State public var currentPage: Int
    public var onFinish: () -> Void

    public init(
        settings: AppSettings = .shared,
        initialPage: Int = 0,
        onFinish: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self._currentPage = State(initialValue: min(max(initialPage, 0), Self.pages.count - 1))
        self.onFinish = onFinish
    }

    public var body: some View {
        let step = Self.pages[min(max(currentPage, 0), Self.pages.count - 1)]

        VStack(spacing: 22) {
            Spacer()

            if step.id == 0, let icon = SettingsView.appIconImage() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 104, height: 104)
            } else {
                Image(systemName: step.systemImage)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(SettingsView.themeBlue)
                    .frame(width: 96, height: 96)
                    .background(SettingsView.themeLightBlue.opacity(0.16), in: RoundedRectangle(cornerRadius: 24))
            }

            Text(step.title)
                .font(.system(size: 22, weight: .bold))

            Text(step.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Spacer()

            HStack(spacing: 8) {
                ForEach(Self.pages) { page in
                    Circle()
                        .fill(page.id == currentPage ? SettingsView.themeBlue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        currentPage -= 1
                    }
                }
                Spacer()
                if currentPage < Self.pages.count - 1 {
                    Button("Next") {
                        currentPage += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        settings.hasCompletedWelcomeTour = true
                        onFinish()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 520, height: 380)
        .tint(SettingsView.themeBlue)
    }
}
