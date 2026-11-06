import AppKit
import CoreGraphics
import SwiftUI

public enum SafeExternalLinks {
    public static func openHTTPS(_ urlString: String) {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

public struct ShortcutRecorderRow: View {
    public let command: ShortcutCommand
    @ObservedObject public var shortcutManager: ShortcutManager
    @State private var isRecording = false
    @State private var keyMonitor: Any?

    public init(command: ShortcutCommand, shortcutManager: ShortcutManager) {
        self.command = command
        self.shortcutManager = shortcutManager
    }

    public var body: some View {
        HStack {
            Text(command.title)
                .font(.system(size: 13))
            Spacer()
            Button {
                toggleRecording()
            } label: {
                Text(isRecording ? "Press keys..." : shortcutManager.binding(for: command).displayString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isRecording ? SettingsView.themeBlue : .primary)
                    .frame(minWidth: 92)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        isRecording ? SettingsView.themeBlue.opacity(0.22) : SettingsView.themeLightBlue.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Button {
                stopRecording()
                shortcutManager.resetToDefault(for: command)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsView.themeBlue)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Reset to Default")
        }
        .padding(.vertical, 2)
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            isRecording = true
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 0x35 {
                    stopRecording()
                    return nil
                }
                let newBinding = KeyBinding(keyCode: event.keyCode, flags: event.modifierFlags)
                shortcutManager.setBinding(newBinding, for: command)
                stopRecording()
                return nil
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

public struct SettingsView: View {
    @ObservedObject public var settings: AppSettings
    @ObservedObject public var shortcutManager: ShortcutManager
    @ObservedObject public var appUpdater: AppUpdater
    public var onOpenWelcomeTour: () -> Void

    @State private var isShowingRestoreAlert = false
    @State private var hoveredTab: SettingsTab?

    public static let appVersionText = "Version 8.1.2 (Build 68)"
    public static let copyrightText = "© Châu Minh Phúc. All rights reserved."
    public static let themeBlue = Color(red: 0.08, green: 0.52, blue: 0.98)
    public static let themeLightBlue = Color(red: 0.38, green: 0.78, blue: 1.0)
    public static let themeGradient = LinearGradient(
        colors: [themeBlue, themeLightBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static func appIconImage() -> NSImage? {
        if let bundled = Bundle.main.image(forResource: "AppIcon") {
            return bundled
        }
        let repoIconURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/AppIcon.png")
        return NSImage(contentsOf: repoIconURL)
    }

    public init(
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared,
        appUpdater: AppUpdater = .shared,
        onOpenWelcomeTour: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.shortcutManager = shortcutManager
        self.appUpdater = appUpdater
        self.onOpenWelcomeTour = onOpenWelcomeTour
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBarHeader
            Divider()
            ScrollView {
                Group {
                    switch settings.selectedSettingsTab {
                    case .general:
                        generalTabContent
                    case .annotation:
                        annotateTabContent
                    case .cursorHighlight:
                        cursorTabContent
                    case .shortcuts:
                        shortcutsTabContent
                    case .about:
                        aboutTabContent
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 660, height: 520)
        .tint(Self.themeBlue)
        .alert("Restore Default Settings?", isPresented: $isShowingRestoreAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restore Defaults", role: .destructive) {
                settings.restoreDefaults()
                shortcutManager.resetAllToDefaults()
            }
        } message: {
            Text("This will reset all preferences and keyboard shortcuts back to their factory defaults.")
        }
    }

    private var tabBarHeader: some View {
        HStack(spacing: 12) {
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = settings.selectedSettingsTab == tab
                let isHovered = hoveredTab == tab
                Button {
                    settings.selectedSettingsTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(width: 82, height: 52)
                    .foregroundStyle(isSelected ? Self.themeBlue : (isHovered ? Color.primary : Color.secondary))
                    .background(
                        isSelected
                            ? Self.themeLightBlue.opacity(0.18)
                            : (isHovered ? Self.themeBlue.opacity(0.08) : Color.clear),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredTab = hovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var generalTabContent: some View {
        Form {
            Section("Startup & System") {
                Toggle("Start at login", isOn: $settings.launchAtLogin)
                Toggle("Highlight Cursor at login", isOn: $settings.highlightCursorAtLogin)
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
                Toggle("Automatically check for updates", isOn: $settings.automaticallyCheckForUpdates)
            }

            Section("Onboarding & Reset") {
                HStack(spacing: 14) {
                    Button("Welcome Tour") {
                        onOpenWelcomeTour()
                    }
                    Button("Restore Defaults", role: .destructive) {
                        isShowingRestoreAlert = true
                    }
                }
                .padding(.top, 6)
            }
        }
        .formStyle(.grouped)
    }

    private var annotateTabContent: some View {
        Form {
            Section("Colors & Stroke") {
                HStack(spacing: 12) {
                    Text("Favorite Colors")
                    Spacer()
                    ForEach(0..<min(5, settings.favColors.count), id: \.self) { idx in
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { settings.favColors[idx].swiftUIColor },
                                set: { newColor in
                                    settings.favColors[idx] = RGBColor(nsColor: NSColor(newColor))
                                }
                            )
                        )
                        .labelsHidden()
                    }
                }

                HStack {
                    Text("Line Weight: \(Int(settings.lineWeight)) pt")
                    Slider(value: $settings.lineWeight, in: settings.minLineWeight...settings.maxLineWeight, step: 1)
                }

                Picker("Blur Style", selection: $settings.blurStyle) {
                    ForEach(BlurStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                HStack {
                    Text("Blur Opacity: \(Int((settings.blurOpacity * 100.0).rounded()))%")
                    Slider(value: $settings.blurOpacity, in: 0.10...1.00, step: 0.05)
                }

                Toggle("Custom Blur Tint Color", isOn: $settings.blurUseCustomColor)

                if settings.blurUseCustomColor {
                    ColorPicker(
                        "Blur Tint Color",
                        selection: Binding(
                            get: { settings.blurCustomColor.swiftUIColor },
                            set: { settings.blurCustomColor = RGBColor(nsColor: NSColor($0)) }
                        )
                    )
                }

                if !CGPreflightScreenCaptureAccess() {
                    HStack {
                        Text("Screen Recording (for HD & Pixelate Blur)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Screen Recording Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                    }
                }

                ColorPicker(
                    "Whiteboard Color",
                    selection: Binding(
                        get: { settings.whiteboardColor.swiftUIColor },
                        set: { settings.whiteboardColor = RGBColor(nsColor: NSColor($0)) }
                    )
                )

                Toggle("Annotation Tool Indicator", isOn: $settings.annotateToolIndicator)
                Toggle("Fade Arrow Tail & Highlight Head", isOn: $settings.annotateArrowTailFade)
            }

            Section("Text Annotations") {
                Picker("Text Font", selection: $settings.annotateFont) {
                    ForEach(AnnotateFontOption.allCases) { fontOption in
                        Text(fontOption.displayName).tag(fontOption)
                    }
                }
                HStack {
                    Text("Text Size: \(Int(settings.annotateFontSize)) pt")
                    Slider(value: $settings.annotateFontSize, in: 12...72, step: 2)
                }
                Toggle("Text Placeholder (\"Type something...\")", isOn: $settings.annotateTextPlaceholder)
            }

            Section("Interactive Mode & Auto Erase") {
                Toggle("Interactive Mode", isOn: $settings.annotateInteractiveMode)
                Picker("Interactive Mode Key", selection: $settings.interactiveModeKey) {
                    ForEach(InteractiveModeKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                Toggle("Auto Erase", isOn: $settings.autoEraseEnabled)
                HStack {
                    Text("Auto Erase Delay: \(String(format: "%.1fs", settings.autoEraseDelay))")
                    Slider(value: $settings.autoEraseDelay, in: 1.0...30.0, step: 0.5)
                }
            }

            Section("Session & Screenshots") {
                Toggle("Save Session", isOn: $settings.annotateSaveSession)
                HStack {
                    Text("Screenshot Save Location")
                    Spacer()
                    Text(settings.screenshotSaveDirectoryPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose...") {
                        chooseScreenshotDirectory()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var cursorTabContent: some View {
        Form {
            Section("Cursor Highlight") {
                Picker("Highlight Shape", selection: $settings.cursorHighlightShape) {
                    ForEach(OverlayShape.allCases) { shape in
                        Text(shape.title).tag(shape)
                    }
                }
                ColorPicker(
                    "Highlight Color",
                    selection: Binding(
                        get: { settings.cursorHighlightColor.swiftUIColor },
                        set: { settings.cursorHighlightColor = RGBColor(nsColor: NSColor($0)) }
                    )
                )
                HStack {
                    Text("Highlight Opacity: \(Int(settings.cursorHighlightFillOpacity * 100))%")
                    Slider(value: $settings.cursorHighlightFillOpacity, in: 0.05...1.0, step: 0.05)
                }
                HStack {
                    Text("Highlight Size: \(Int(settings.cursorHighlightSize)) px")
                    Slider(value: $settings.cursorHighlightSize, in: 20...250, step: 5)
                }
                Picker("Border Style", selection: $settings.cursorHighlightBorderStyle) {
                    ForEach(CursorBorderStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                Toggle("Highlight Glow", isOn: $settings.highlightGlow)
                Picker("Click Animation", selection: $settings.cursorClickAnimation) {
                    ForEach(CursorClickAnimation.allCases) { anim in
                        Text(anim.title).tag(anim)
                    }
                }
                Toggle("Show only on click", isOn: $settings.highlightShowOnlyOnClick)
                Toggle("Turn off when inactive", isOn: $settings.autoHideCursorHighlightWhenIdle)
            }

            Section("Cursor Spotlight") {
                Picker("Spotlight Shape", selection: $settings.spotlightShape) {
                    ForEach(OverlayShape.allCases) { shape in
                        Text(shape.title).tag(shape)
                    }
                }
                HStack {
                    Text("Spotlight Size: \(Int(settings.spotlightSize)) px")
                    Slider(value: $settings.spotlightSize, in: 40...400, step: 10)
                }
                HStack {
                    Text("Background Opacity: \(Int(settings.spotlightCurtainOpacity * 100))%")
                    Slider(value: $settings.spotlightCurtainOpacity, in: 0.1...0.95, step: 0.05)
                }
            }

            Section("Cursor Zoom") {
                Picker("Zoom Shape", selection: $settings.zoomShape) {
                    ForEach(OverlayShape.allCases) { shape in
                        Text(shape.title).tag(shape)
                    }
                }
                HStack {
                    Text("Zoom Level: \(String(format: "%.2fx", settings.zoomLevel))")
                    Slider(value: $settings.zoomLevel, in: 1.5...5.0, step: 0.25)
                }
                HStack {
                    Text("Zoom Size: \(Int(settings.zoomSize)) px")
                    Slider(value: $settings.zoomSize, in: 80...450, step: 10)
                }
                ColorPicker(
                    "Zoom Border Color",
                    selection: Binding(
                        get: { settings.zoomBorderColor.swiftUIColor },
                        set: { settings.zoomBorderColor = RGBColor(nsColor: NSColor($0)) }
                    )
                )
                Toggle("Dim Background", isOn: $settings.zoomDimBackground)
                Toggle("Full Screen Zoom", isOn: $settings.zoomFullScreen)
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Customize keyboard shortcuts or restore defaults.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset All to Default") {
                    shortcutManager.resetAllToDefaults()
                }
            }

            ForEach(ShortcutCategory.allCases) { category in
                GroupBox(label: Text(category.title).font(.headline)) {
                    VStack(spacing: 4) {
                        ForEach(category.commands) { command in
                            ShortcutRecorderRow(command: command, shortcutManager: shortcutManager)
                            if command != category.commands.last {
                                Divider()
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private var aboutTabContent: some View {
        VStack(spacing: 14) {
            if let icon = Self.appIconImage() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 96, height: 96)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Self.themeGradient)
                        .frame(width: 84, height: 84)
                    Image(systemName: "tv.and.mediabox")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text("ScreenEditing")
                .font(.system(size: 22, weight: .bold))

            Text("Version \(appUpdater.currentVersion) (Build 68)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(Self.copyrightText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            updateStatusSection
                .padding(.vertical, 4)

            HStack(spacing: 14) {
                Button("X (Twitter)") {
                    SafeExternalLinks.openHTTPS("https://x.com/ChauMinhPhuc")
                }
                Button("YouTube") {
                    SafeExternalLinks.openHTTPS("https://www.youtube.com/@BumLowkey")
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var updateStatusSection: some View {
        switch appUpdater.status {
        case .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        case .upToDate(let version):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("ScreenEditing \(version) is up to date.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button("Check Again") {
                    appUpdater.checkForUpdates(mode: .userInitiated)
                }
                .controlSize(.small)
            }
        case .updateAvailable(let release):
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Self.themeBlue)
                Text("Update available: \(release.tagName)")
                    .font(.system(size: 12, weight: .semibold))
                Button("Download & Install Update") {
                    appUpdater.downloadAndInstall(release: release)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        case .downloading(let progress, let version):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 220)
                Text("Downloading \(version)...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .installing(let version):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Installing \(version)...")
                    .font(.system(size: 12))
            }
        case .failed(let message):
            VStack(spacing: 6) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Button("Check for Updates") {
                    appUpdater.checkForUpdates(mode: .userInitiated)
                }
                .controlSize(.small)
            }
        case .idle:
            Button("Check for Updates") {
                appUpdater.checkForUpdates(mode: .userInitiated)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func chooseScreenshotDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select"
        if openPanel.runModal() == .OK, let url = openPanel.url {
            if let valid = Screenshotter.validateDirectoryPath(url.path) {
                settings.screenshotSaveDirectoryPath = valid.path
            }
        }
    }
}
