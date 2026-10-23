import AppKit
import Combine
import SwiftUI

public final class PresentifyAppController: NSObject, NSApplicationDelegate {
    public let settings: AppSettings
    public let shortcutManager: ShortcutManager
    public let annotateController: AnnotateOverlayController
    public let highlightController: CursorHighlightWindowController
    public let spotlightController: CursorSpotlightWindowController
    public let zoomController: CursorZoomWindowController
    public let dockMenuController: PresentifyDockMenuController

    public private(set) var statusItem: NSStatusItem?
    public private(set) var menuPopover: NSPopover?
    public private(set) var settingsWindow: NSWindow?
    public private(set) var welcomeTourWindow: NSWindow?

    private var cancellables: Set<AnyCancellable> = []

    public init(
        settings: AppSettings = .shared,
        shortcutManager: ShortcutManager = .shared
    ) {
        self.settings = settings
        self.shortcutManager = shortcutManager
        self.annotateController = AnnotateOverlayController(settings: settings, shortcutManager: shortcutManager)
        self.highlightController = CursorHighlightWindowController(settings: settings)
        self.spotlightController = CursorSpotlightWindowController(settings: settings)
        self.zoomController = CursorZoomWindowController(settings: settings, shortcutManager: shortcutManager)
        self.dockMenuController = PresentifyDockMenuController(settings: settings)
        super.init()

        dockMenuController.onToggleAnnotate = { [weak self] in self?.annotateController.toggleAnnotation() }
        dockMenuController.onToggleHighlight = { [weak self] in self?.highlightController.toggle() }
        dockMenuController.onToggleSpotlight = { [weak self] in self?.spotlightController.toggle() }
        dockMenuController.onToggleZoom = { [weak self] in self?.zoomController.toggle() }
        dockMenuController.onOpenSettings = { [weak self] in self?.openSettingsWindow() }

        shortcutManager.onGlobalCommand = { [weak self] command in
            self?.handleGlobalShortcut(command)
        }
        bindPreferences()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockVisibilityPolicy()
        setupMenuBarStatusItem()
        shortcutManager.registerGlobalHotKeys()

        if settings.highlightCursorAtLogin {
            highlightController.show()
        }

        if !settings.hasCompletedWelcomeTour {
            openWelcomeTourWindow()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        shortcutManager.unregisterGlobalHotKeys()
        annotateController.hideAnnotation()
        highlightController.hide()
        spotlightController.hide()
        zoomController.hide()
    }

    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        dockMenuController.buildDockMenu()
    }

    public func handleGlobalShortcut(_ command: ShortcutCommand) {
        switch command {
        case .toggleAnnotateScreen:
            annotateController.toggleAnnotation()
        case .toggleAnnotateControls:
            annotateController.toggleAnnotateControls()
        case .toggleHighlightCursor:
            highlightController.toggle()
            if settings.isHighlightingCursor {
                annotateController.toastController.showToast(.highlightMode, message: "Cursor Highlight Active")
            }
        case .toggleSpotlightCursor:
            spotlightController.toggle()
        case .toggleZoomCursor:
            zoomController.toggle()
        default:
            break
        }
    }

    public func openSettingsWindow(selectingTab tab: SettingsTab? = nil) {
        if let tab {
            settings.selectedSettingsTab = tab
        }
        menuPopover?.performClose(nil)

        if settingsWindow == nil {
            let rootView = SettingsView(
                settings: settings,
                shortcutManager: shortcutManager,
                onOpenWelcomeTour: { [weak self] in self?.openWelcomeTourWindow() }
            )
            let hosting = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "ScreenEditing Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    public func openWelcomeTourWindow() {
        menuPopover?.performClose(nil)
        if welcomeTourWindow == nil {
            let tourView = WelcomeTourView(
                settings: settings,
                onFinish: { [weak self] in self?.welcomeTourWindow?.close() }
            )
            let hosting = NSHostingController(rootView: tourView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Welcome to ScreenEditing"
            window.styleMask = [.titled, .closable]
            window.center()
            window.isReleasedWhenClosed = false
            welcomeTourWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        welcomeTourWindow?.makeKeyAndOrderFront(nil)
    }

    private func setupMenuBarStatusItem() {
        guard settings.showMenuBarIcon else {
            if let existing = statusItem {
                NSStatusBar.system.removeStatusItem(existing)
                statusItem = nil
            }
            return
        }

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.image = NSImage(systemSymbolName: "pencil.tip.crop.circle", accessibilityDescription: "ScreenEditing")
                button.target = self
                button.action = #selector(toggleStatusPopover(_:))
            }
            statusItem = item
        }

        if menuPopover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            let menuView = PresentifyMenuView(
                settings: settings,
                shortcutManager: shortcutManager,
                onToggleAnnotate: { [weak self] in
                    self?.menuPopover?.performClose(nil)
                    self?.annotateController.toggleAnnotation()
                },
                onToggleAnnotateControls: { [weak self] in
                    self?.annotateController.toggleAnnotateControls()
                },
                onToggleHighlight: { [weak self] in
                    self?.highlightController.toggle()
                },
                onToggleSpotlight: { [weak self] in
                    self?.spotlightController.toggle()
                },
                onToggleZoom: { [weak self] in
                    self?.zoomController.toggle()
                },
                onOpenSettings: { [weak self] in
                    self?.openSettingsWindow()
                },
                onOpenWelcomeTour: { [weak self] in
                    self?.openWelcomeTourWindow()
                }
            )
            popover.contentViewController = NSHostingController(rootView: menuView)
            menuPopover = popover
        }
    }

    @objc private func toggleStatusPopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = menuPopover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func applyDockVisibilityPolicy() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let policy: NSApplication.ActivationPolicy = settings.showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }

    private func bindPreferences() {
        settings.$showMenuBarIcon
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.setupMenuBarStatusItem() }
            .store(in: &cancellables)

        settings.$showDockIcon
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyDockVisibilityPolicy() }
            .store(in: &cancellables)
    }
}
