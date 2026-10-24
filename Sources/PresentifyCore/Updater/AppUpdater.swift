import AppKit
import Combine
import Foundation
import SwiftUI

public struct ReleaseAssetInfo: Codable, Equatable, Sendable {
    public let name: String
    public let browserDownloadURL: String
    public let apiURL: String?
    public let size: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case apiURL = "url"
        case size
    }

    public init(
        name: String,
        browserDownloadURL: String,
        apiURL: String? = nil,
        size: Int? = nil
    ) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
        self.apiURL = apiURL
        self.size = size
    }
}

public struct GitHubReleaseInfo: Codable, Equatable, Sendable {
    public let tagName: String
    public let name: String
    public let body: String
    public let htmlURL: String
    public let assets: [ReleaseAssetInfo]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }

    public init(
        tagName: String,
        name: String,
        body: String,
        htmlURL: String,
        assets: [ReleaseAssetInfo] = []
    ) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.htmlURL = htmlURL
        self.assets = assets
    }
}

public enum UpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(release: GitHubReleaseInfo)
    case downloading(progress: Double, version: String)
    case installing(version: String)
    case failed(message: String)
}

public enum UpdateCheckMode: Sendable {
    case automatic
    case userInitiated
}

public struct ReleaseHTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public final class AppUpdater: ObservableObject {
    public static let shared = AppUpdater()

    private static let allowedDownloadHosts: Set<String> = [
        "github.com",
        "objects.githubusercontent.com",
        "api.github.com",
        "release-assets.githubusercontent.com"
    ]

    @Published public var status: UpdateStatus = .idle
    @Published public var lastCheckedDate: Date?

    public let settings: AppSettings
    public let repositorySlug: String
    public var onUpdateAvailable: ((GitHubReleaseInfo) -> Void)?

    private var checkTimer: Timer?
    private var initialCheckWorkItem: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        settings: AppSettings = .shared,
        repositorySlug: String = "minhphuc010194/ScreenEditing"
    ) {
        self.settings = settings
        self.repositorySlug = repositorySlug
        bindSettings()
    }

    deinit {
        stopAutomaticChecks()
    }

    public var currentVersion: String {
        let bundleID = Bundle.main.bundleIdentifier
        let isAppBundle = bundleID == "com.screenediting.app" || bundleID == "com.softal.presentify"
        guard isAppBundle,
              let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "8.1.2"
        }
        return version.isEmpty ? "8.1.2" : version
    }

    public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = normalizedVersionComponents(candidate)
        let currentParts = normalizedVersionComponents(current)
        let maxCount = max(candidateParts.count, currentParts.count)
        for index in 0..<maxCount {
            let candidateValue = index < candidateParts.count ? candidateParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0
            if candidateValue != currentValue {
                return candidateValue > currentValue
            }
        }
        return false
    }

    private static func normalizedVersionComponents(_ version: String) -> [Int] {
        var trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        let coreVersion = trimmed.split(separator: "-", maxSplits: 1).first.map(String.init) ?? trimmed
        return coreVersion.split(separator: ".").map { Int($0) ?? 0 }
    }

    public static func validatedZipAssetURL(in assets: [ReleaseAssetInfo]) -> URL? {
        for asset in assets where asset.name.lowercased().hasSuffix(".zip") {
            guard let url = URL(string: asset.browserDownloadURL),
                  let host = url.host?.lowercased() else {
                continue
            }
            let isHTTPS = url.scheme?.lowercased() == "https"
            let isAllowedHost = allowedDownloadHosts.contains(host)
            if isHTTPS && isAllowedHost {
                return url
            }
        }
        return nil
    }

    public static func validatedAPIAssetURL(in assets: [ReleaseAssetInfo]) -> URL? {
        for asset in assets where asset.name.lowercased().hasSuffix(".zip") {
            guard let rawAPI = asset.apiURL,
                  let url = URL(string: rawAPI) else {
                continue
            }
            let isHTTPS = url.scheme?.lowercased() == "https"
            let isGitHubAPI = url.host?.lowercased() == "api.github.com"
            if isHTTPS && isGitHubAPI {
                return url
            }
        }
        return nil
    }

    private static func resolveLocalGitHubToken() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let envToken = env["GITHUB_TOKEN"] ?? env["GH_TOKEN"] {
            let trimmed = envToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        let candidatePaths = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        for path in candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["auth", "token"]
            let outPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    if let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !token.isEmpty {
                        return token
                    }
                }
            } catch {
                continue
            }
        }
        return nil
    }

    public func startAutomaticChecks() {
        stopAutomaticChecks()
        guard settings.automaticallyCheckForUpdates else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.settings.automaticallyCheckForUpdates else { return }
            self.checkForUpdates(mode: .automatic)
        }
        initialCheckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)

        checkTimer = Timer.scheduledTimer(withTimeInterval: 6.0 * 3600.0, repeats: true) { [weak self] _ in
            guard let self, self.settings.automaticallyCheckForUpdates else { return }
            self.checkForUpdates(mode: .automatic)
        }
    }

    public func stopAutomaticChecks() {
        initialCheckWorkItem?.cancel()
        initialCheckWorkItem = nil
        checkTimer?.invalidate()
        checkTimer = nil
    }

    public func checkForUpdates(mode: UpdateCheckMode = .automatic) {
        guard let url = URL(string: "https://api.github.com/repos/\(repositorySlug)/releases/latest") else {
            status = .failed(message: "Invalid repository URL.")
            return
        }

        status = .checking
        var request = URLRequest(url: url, timeoutInterval: 15.0)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ScreenEditing/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        if let token = Self.resolveLocalGitHubToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    if mode == .userInitiated {
                        self.status = .failed(message: error.localizedDescription)
                    } else {
                        self.status = .idle
                    }
                    return
                }
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let payload = data ?? Data()
                self.processReleaseResponse(
                    ReleaseHTTPResponse(data: payload, statusCode: statusCode),
                    mode: mode
                )
            }
        }.resume()
    }

    @discardableResult
    public func processReleaseResponse(
        _ response: ReleaseHTTPResponse,
        mode: UpdateCheckMode = .automatic
    ) -> UpdateStatus {
        lastCheckedDate = Date()
        if response.statusCode == 404 {
            let upToDate = UpdateStatus.upToDate(currentVersion: currentVersion)
            status = upToDate
            return upToDate
        }
        let isSuccessStatus = response.statusCode >= 200 && response.statusCode < 300
        guard isSuccessStatus else {
            let failed = UpdateStatus.failed(message: "GitHub API returned HTTP \(response.statusCode).")
            status = failed
            return failed
        }
        guard let release = try? JSONDecoder().decode(GitHubReleaseInfo.self, from: response.data) else {
            let failed = UpdateStatus.failed(message: "Unable to parse release metadata.")
            status = failed
            return failed
        }
        let isNewer = Self.isVersion(release.tagName, newerThan: currentVersion)
        guard isNewer else {
            let upToDate = UpdateStatus.upToDate(currentVersion: currentVersion)
            status = upToDate
            return upToDate
        }
        let isSkippedInAutoMode = mode == .automatic && release.tagName == settings.skippedUpdateVersion
        if isSkippedInAutoMode {
            let upToDate = UpdateStatus.upToDate(currentVersion: currentVersion)
            status = upToDate
            return upToDate
        }
        let available = UpdateStatus.updateAvailable(release: release)
        status = available
        onUpdateAvailable?(release)
        return available
    }

    public func skipRelease(_ release: GitHubReleaseInfo) {
        settings.skippedUpdateVersion = release.tagName
        status = .upToDate(currentVersion: currentVersion)
    }

    public func downloadAndInstall(release: GitHubReleaseInfo) {
        let token = Self.resolveLocalGitHubToken()
        let downloadTargetURL: URL
        var useOctetStreamAccept = false

        if let token, let apiURL = Self.validatedAPIAssetURL(in: release.assets) {
            downloadTargetURL = apiURL
            useOctetStreamAccept = !token.isEmpty
        } else if let zipURL = Self.validatedZipAssetURL(in: release.assets) {
            downloadTargetURL = zipURL
        } else {
            SafeExternalLinks.openHTTPS(release.htmlURL)
            status = .idle
            return
        }

        status = .downloading(progress: 0.15, version: release.tagName)
        var request = URLRequest(url: downloadTargetURL, timeoutInterval: 120.0)
        request.setValue("ScreenEditing/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if useOctetStreamAccept {
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        }

        let session = URLSession(
            configuration: .ephemeral,
            delegate: RedirectStrippingSessionDelegate(allowedHosts: Self.allowedDownloadHosts),
            delegateQueue: nil
        )
        session.downloadTask(with: request) { [weak self] tempLocalURL, response, error in
            defer { session.finishTasksAndInvalidate() }
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.status = .failed(message: error.localizedDescription)
                }
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let isSuccessStatus = statusCode >= 200 && statusCode < 300
            guard isSuccessStatus, let tempLocalURL else {
                DispatchQueue.main.async {
                    self.status = .failed(message: "Failed to download update archive (HTTP \(statusCode)).")
                }
                return
            }

            DispatchQueue.main.async {
                self.status = .downloading(progress: 0.75, version: release.tagName)
            }
            self.extractAndInstallArchive(from: tempLocalURL, version: release.tagName)
        }.resume()
    }

    private func extractAndInstallArchive(from downloadedURL: URL, version: String) {
        let fileManager = FileManager.default
        let stagingDir = fileManager.temporaryDirectory
            .appendingPathComponent("ScreenEditing-Update-\(UUID().uuidString)", isDirectory: true)
        let zipFileURL = stagingDir.appendingPathComponent("ScreenEditing.app.zip")
        let extractDir = stagingDir.appendingPathComponent("Extracted", isDirectory: true)

        do {
            try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try fileManager.moveItem(at: downloadedURL, to: zipFileURL)

            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzipProcess.arguments = ["-x", "-k", zipFileURL.path, extractDir.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()

            guard unzipProcess.terminationStatus == 0 else {
                throw NSError(
                    domain: "ScreenEditingUpdater",
                    code: Int(unzipProcess.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to extract update archive."]
                )
            }

            let extractedAppURL = extractDir.appendingPathComponent("ScreenEditing.app", isDirectory: true)
            let extractedBinaryURL = extractedAppURL.appendingPathComponent("Contents/MacOS/ScreenEditing")
            guard fileManager.isExecutableFile(atPath: extractedBinaryURL.path) else {
                throw NSError(
                    domain: "ScreenEditingUpdater",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Extracted update does not contain a valid ScreenEditing.app bundle."]
                )
            }

            DispatchQueue.main.async {
                self.status = .installing(version: version)
            }

            let targetAppURL = resolveInstallDestinationURL()
            if fileManager.fileExists(atPath: targetAppURL.path) {
                try fileManager.removeItem(at: targetAppURL)
            }

            let copyProcess = Process()
            copyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            copyProcess.arguments = [extractedAppURL.path, targetAppURL.path]
            try copyProcess.run()
            copyProcess.waitUntilExit()

            guard copyProcess.terminationStatus == 0 else {
                throw NSError(
                    domain: "ScreenEditingUpdater",
                    code: Int(copyProcess.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to copy ScreenEditing.app to \(targetAppURL.path)."]
                )
            }

            try? fileManager.removeItem(at: stagingDir)

            DispatchQueue.main.async {
                let relaunchProcess = Process()
                relaunchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                relaunchProcess.arguments = ["-n", targetAppURL.path]
                try? relaunchProcess.run()
                NSApp.terminate(nil)
            }
        } catch {
            try? fileManager.removeItem(at: stagingDir)
            DispatchQueue.main.async {
                self.status = .failed(message: error.localizedDescription)
            }
        }
    }

    private func resolveInstallDestinationURL() -> URL {
        let currentBundleURL = Bundle.main.bundleURL
        let isRunningFromAppBundle = currentBundleURL.pathExtension == "app"
        let isParentWritable = FileManager.default.isWritableFile(atPath: currentBundleURL.deletingLastPathComponent().path)
        if isRunningFromAppBundle && isParentWritable {
            return currentBundleURL
        }
        return URL(fileURLWithPath: "/Applications/ScreenEditing.app", isDirectory: true)
    }

    private func bindSettings() {
        settings.$automaticallyCheckForUpdates
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.startAutomaticChecks()
                } else {
                    self.stopAutomaticChecks()
                }
            }
            .store(in: &cancellables)
    }
}

public struct UpdateNotificationView: View {
    @ObservedObject public var updater: AppUpdater
    public let release: GitHubReleaseInfo
    public var onSkip: () -> Void
    public var onDismiss: () -> Void

    public init(
        updater: AppUpdater = .shared,
        release: GitHubReleaseInfo,
        onSkip: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.updater = updater
        self.release = release
        self.onSkip = onSkip
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.54, green: 0.23, blue: 0.94),
                                    Color(red: 0.36, green: 0.14, blue: 0.76)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("A new version of ScreenEditing is available!")
                        .font(.system(size: 16, weight: .bold))
                    Text("ScreenEditing \(release.tagName) is now available — you have \(updater.currentVersion).")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Release Notes")
                .font(.system(size: 12, weight: .semibold))

            ScrollView {
                Text(release.body.isEmpty ? "Bug fixes and performance improvements." : release.body)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 140)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            statusAndActionFooter
        }
        .padding(22)
        .frame(width: 480)
    }

    @ViewBuilder
    private var statusAndActionFooter: some View {
        switch updater.status {
        case .downloading(let progress, _):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress)
                Text("Downloading update...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Installing update and relaunching ScreenEditing...")
                    .font(.system(size: 12, weight: .medium))
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                HStack {
                    Button("View Release on GitHub") {
                        SafeExternalLinks.openHTTPS(release.htmlURL)
                    }
                    Spacer()
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
        default:
            HStack {
                Button("Skip This Version") {
                    updater.skipRelease(release)
                    onSkip()
                }
                Spacer()
                Button("Later") {
                    onDismiss()
                }
                Button("Download & Install Now") {
                    updater.downloadAndInstall(release: release)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private final class RedirectStrippingSessionDelegate: NSObject, URLSessionTaskDelegate {
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              let host = url.host?.lowercased() else {
            completionHandler(nil)
            return
        }
        let isHTTPS = url.scheme?.lowercased() == "https"
        let isAllowedHost = allowedHosts.contains(host)
        guard isHTTPS && isAllowedHost else {
            completionHandler(nil)
            return
        }
        var modified = request
        if host != "api.github.com" {
            modified.setValue(nil, forHTTPHeaderField: "Authorization")
            modified.setValue("*/*", forHTTPHeaderField: "Accept")
        }
        completionHandler(modified)
    }
}
