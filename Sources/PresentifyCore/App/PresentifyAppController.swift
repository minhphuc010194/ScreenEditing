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

    private var popoverGlobalClickMonitor: Any?
    private var popoverLocalClickMonitor: Any?
    private var appKeyDownMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
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

        annotateController.onRequestOpenSettings = { [weak self] in self?.openSettingsWindow() }
        dockMenuController.onToggleAnnotate = { [weak self] in self?.annotateController.toggleAnnotation() }
        dockMenuController.onToggleHighlight = { [weak self] in self?.highlightController.toggle() }
        dockMenuController.onToggleSpotlight = { [weak self] in self?.spotlightController.toggle() }
        dockMenuController.onToggleZoom = { [weak self] in self?.zoomController.toggle() }
        dockMenuController.onOpenSettings = { [weak self] in self?.openSettingsWindow() }

        shortcutManager.onGlobalCommand = { [weak self] command in
            self?.handleGlobalShortcut(command)
        }
        if NSApp != nil {
            setupMainMenu()
        }
        bindPreferences()
    }

    deinit {
        stopPopoverMonitors()
        stopAppKeyMonitor()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        startAppKeyMonitor()
        applyDockVisibilityPolicy()
        setupMenuBarStatusItem()
        shortcutManager.registerGlobalHotKeys()

        if settings.highlightCursorAtLogin {
            highlightController.show()
        }

        if !settings.hasCompletedWelcomeTour {
            openWelcomeTourWindow()
        } else {
            openSettingsWindow()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openSettingsWindow()
        }
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        stopPopoverMonitors()
        stopAppKeyMonitor()
        shortcutManager.unregisterGlobalHotKeys()
        annotateController.hideAnnotation()
        highlightController.hide()
        spotlightController.hide()
        zoomController.hide()
    }

    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        dockMenuController.buildDockMenu()
    }

    public func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "ScreenEditing")
        let aboutItem = NSMenuItem(
            title: "About ScreenEditing",
            action: #selector(openAboutTab),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide ScreenEditing",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(hideItem)

        let quitItem = NSMenuItem(
            title: "Quit ScreenEditing",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(AnnotateCanvasView.undo(_:)), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: #selector(AnnotateCanvasView.redo(_:)), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu

        NSApp?.mainMenu = mainMenu
    }

    @objc private func openAboutTab() {
        openSettingsWindow(selectingTab: .about)
    }

    @objc private func openSettingsFromMenu() {
        openSettingsWindow()
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
        closeMenuPopover()

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
        closeMenuPopover()
        if welcomeTourWindow == nil {
            let tourView = WelcomeTourView(
                settings: settings,
                onFinish: { [weak self] in
                    self?.welcomeTourWindow?.close()
                    self?.openSettingsWindow()
                }
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

    public func closeMenuPopover() {
        menuPopover?.performClose(nil)
        stopPopoverMonitors()
    }

    private func setupMenuBarStatusItem() {
        guard settings.showMenuBarIcon else {
            closeMenuPopover()
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
                    self?.closeMenuPopover()
                    self?.annotateController.toggleAnnotation()
                },
                onToggleAnnotateControls: { [weak self] in
                    self?.closeMenuPopover()
                    self?.annotateController.toggleAnnotateControls()
                },
                onToggleHighlight: { [weak self] in
                    self?.closeMenuPopover()
                    self?.highlightController.toggle()
                },
                onToggleSpotlight: { [weak self] in
                    self?.closeMenuPopover()
                    self?.spotlightController.toggle()
                },
                onToggleZoom: { [weak self] in
                    self?.closeMenuPopover()
                    self?.zoomController.toggle()
                },
                onOpenSettings: { [weak self] in
                    self?.closeMenuPopover()
                    self?.openSettingsWindow()
                },
                onOpenWelcomeTour: { [weak self] in
                    self?.closeMenuPopover()
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
            closeMenuPopover()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            startPopoverMonitors()
        }
    }

    private func startPopoverMonitors() {
        stopPopoverMonitors()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        popoverGlobalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.closeMenuPopover()
        }
        popoverLocalClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self, self.menuPopover?.isShown == true else { return event }
            let popoverWindow = self.menuPopover?.contentViewController?.view.window
            let statusButtonWindow = self.statusItem?.button?.window
            if event.window !== popoverWindow && event.window !== statusButtonWindow {
                self.closeMenuPopover()
            }
            return event
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeMenuPopover()
        }
    }

    private func stopPopoverMonitors() {
        if let monitor = popoverGlobalClickMonitor {
            NSEvent.removeMonitor(monitor)
            popoverGlobalClickMonitor = nil
        }
        if let monitor = popoverLocalClickMonitor {
            NSEvent.removeMonitor(monitor)
            popoverLocalClickMonitor = nil
        }
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            resignActiveObserver = nil
        }
    }

    public func handleAppKeyDown(keyCode: UInt16, modifiers: UInt) -> Bool {
        let normMods = modifiers & KeyBinding.relevantModifiersMask
        if keyCode == 0x0C && normMods == KeyBinding.commandMask {
            NSApp.terminate(nil)
            return true
        }
        if keyCode == 0x2B && normMods == KeyBinding.commandMask {
            openSettingsWindow()
            return true
        }
        if keyCode == 0x0D && normMods == KeyBinding.commandMask {
            if menuPopover?.isShown == true {
                closeMenuPopover()
                return true
            }
            if settings.isAnnotating {
                annotateController.hideAnnotation()
                return true
            }
            if welcomeTourWindow?.isKeyWindow == true {
                welcomeTourWindow?.close()
                return true
            }
            if settingsWindow?.isKeyWindow == true {
                settingsWindow?.close()
                return true
            }
        }
        if keyCode == 0x35 && normMods == 0 {
            if menuPopover?.isShown == true {
                closeMenuPopover()
                return true
            }
            if !settings.isAnnotating {
                if settings.isZoomingCursor {
                    zoomController.hide()
                    return true
                }
                if settings.isSpotlightingCursor {
                    spotlightController.hide()
                    return true
                }
                if settings.isHighlightingCursor {
                    highlightController.hide()
                    return true
                }
            }
        }
        let hasHighlightOrSpotlight = settings.isHighlightingCursor || settings.isSpotlightingCursor
        let isCursorOverlayActive = hasHighlightOrSpotlight || settings.isZoomingCursor
        if !settings.isAnnotating && isCursorOverlayActive {
            if zoomController.handleCursorShortcut(keyCode: keyCode, modifiers: modifiers) {
                return true
            }
        }
        return false
    }

    private func startAppKeyMonitor() {
        stopAppKeyMonitor()
        appKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let rawMods = UInt(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
            if self.handleAppKeyDown(keyCode: event.keyCode, modifiers: rawMods) {
                return nil
            }
            return event
        }
    }

    private func stopAppKeyMonitor() {
        if let monitor = appKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            appKeyDownMonitor = nil
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
