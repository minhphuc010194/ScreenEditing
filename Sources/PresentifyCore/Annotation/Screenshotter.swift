import AppKit
import Foundation
import UserNotifications

public enum Screenshotter {
    public static func validateDirectoryPath(_ rawPath: String) -> URL? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\0") else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists && isDirectory.boolValue else { return nil }
        guard FileManager.default.isWritableFile(atPath: url.path) else { return nil }
        return url
    }

    public static func renderViewToImage(_ view: NSView) -> NSImage? {
        let bounds = view.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return nil }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    public static func renderViewToPNGData(_ view: NSView) -> Data? {
        let bounds = view.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return nil }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    @discardableResult
    public static func saveViewScreenshot(
        _ view: NSView,
        directoryPath: String,
        playSound: Bool = false
    ) -> URL? {
        guard let pngData = renderViewToPNGData(view) else { return nil }
        let targetDir = validateDirectoryPath(directoryPath)
            ?? validateDirectoryPath(AppSettings.defaultScreenshotDirectory)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss-SSS"
        let filename = "ScreenEditing-Screenshot-\(formatter.string(from: Date())).png"
        let fileURL = targetDir.appendingPathComponent(filename, isDirectory: false)

        do {
            try pngData.write(to: fileURL, options: .atomic)
            if playSound {
                NSSound(named: NSSound.Name("Tink"))?.play()
            }
            postNotificationIfBundled(title: "Screenshot Saved", body: fileURL.lastPathComponent)
            return fileURL
        } catch {
            return nil
        }
    }

    @discardableResult
    public static func copyViewScreenshotToPasteboard(
        _ view: NSView,
        pasteboard: NSPasteboard = .general,
        playSound: Bool = false
    ) -> Bool {
        guard let pngData = renderViewToPNGData(view) else { return false }
        pasteboard.clearContents()
        let wrote = pasteboard.setData(pngData, forType: .png)
        if wrote {
            if playSound {
                NSSound(named: NSSound.Name("Tink"))?.play()
            }
            postNotificationIfBundled(title: "Screenshot Copied", body: "Copied annotated screen to clipboard.")
        }
        return wrote
    }

    private static func postNotificationIfBundled(title: String, body: String) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
