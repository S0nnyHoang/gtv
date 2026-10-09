import AppKit
import Sparkle

/// Tự động cập nhật bằng Sparkle.
///
/// Chạy trong tiến trình bộ gõ (luôn chạy ngầm, nên kiểm tra định kỳ được) nhưng cập nhật
/// **GTV.app** trong Applications: GTV.app là bundle chứa cấu hình Sparkle (SUFeedURL, SUPublicEDKey)
/// và là bundle được thay khi cài bản mới. Cài xong, Sparkle mở lại GTV.app; GTV.app cập nhật bộ gõ
/// tại chỗ như mọi lần mở.
///
/// Thông tin bản mới: `appcast.xml` đính kèm release mới nhất trên GitHub (workflow Release tạo và ký
/// bằng khoá EdDSA).
final class Updater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let shared = Updater()

    private var updater: SPUUpdater?
    private var userDriver: SPUStandardUserDriver?
    private var hostURL: URL?

    var isAvailable: Bool { updater != nil }

    var automaticallyChecks: Bool {
        get { updater?.automaticallyChecksForUpdates ?? false }
        set { updater?.automaticallyChecksForUpdates = newValue }
    }

    func start() {
        // Không cập nhật được bản chạy thẳng từ DMG (ổ chỉ đọc) hoặc GTV.app đời cũ chưa có cấu hình Sparkle.
        guard let appURL = Settings.launcherURL(), !appURL.path.hasPrefix("/Volumes/"),
              let host = Bundle(url: appURL), host.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            DebugLog.write("Sparkle: không có GTV.app phù hợp để cập nhật")
            return
        }
        hostURL = appURL
        syncInputMethodIfNeeded()
        let driver = SPUStandardUserDriver(hostBundle: host, delegate: self)
        let updater = SPUUpdater(hostBundle: host, applicationBundle: host, userDriver: driver, delegate: self)
        do {
            try updater.start()
            self.userDriver = driver
            self.updater = updater
            DebugLog.write("Sparkle: đã khởi động cho \(appURL.path), phiên bản \(host.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "?")")
        } catch {
            DebugLog.write("Sparkle: không khởi động được: \(error.localizedDescription)")
        }
    }

    /// Số build (CFBundleVersion) của GTV.app trên đĩa (đọc mới, không dùng bộ đệm của Bundle).
    private func installedBuild() -> String {
        guard let url = hostURL?.appendingPathComponent("Contents/Info.plist"),
              let info = NSDictionary(contentsOf: url) else { return "0" }
        return info["CFBundleVersion"] as? String ?? "0"
    }

    private var ownBuild: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }

    /// GTV.app trên đĩa mới hơn bộ gõ đang chạy (so sánh như Sparkle: 1.11.1 > 1.11 > 1.10.5).
    private var installedIsNewer: Bool {
        SUStandardVersionComparator.default.compareVersion(ownBuild, toVersion: installedBuild()) == .orderedAscending
    }

    /// GTV.app mới hơn bộ gõ đang chạy (vd. vừa cập nhật nhưng bộ gõ chưa được thay): chạy GTV.app để nó
    /// cập nhật bộ gõ tại chỗ (tiến trình này sẽ bị thay bằng bản mới).
    private func syncInputMethodIfNeeded() {
        guard installedIsNewer else { return }
        DebugLog.write("GTV.app (\(installedBuild())) mới hơn bộ gõ (\(ownBuild)): chạy GTV.app để cập nhật bộ gõ")
        Settings.runLauncher([])
    }

    /// Sparkle chỉ mở lại app sau khi cài nếu app đó đang chạy; GTV.app thường không chạy (bộ gõ mới là
    /// tiến trình chạy ngầm), nên tự theo dõi: khi GTV.app trên đĩa đã là bản mới thì chạy nó.
    private func watchForInstall(deadline: Date) {
        if installedIsNewer {
            syncInputMethodIfNeeded()
        } else if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.watchForInstall(deadline: deadline)
            }
        }
    }

    /// Người dùng chọn "Kiểm tra cập nhật…".
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updater?.checkForUpdates()
    }

    // MARK: - SPUUpdaterDelegate

    /// Cho phép đổi nguồn appcast để thử nghiệm: `defaults write com.gtv.inputmethod.GTV updateFeedURL <url>`.
    func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: "updateFeedURL")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        DebugLog.write("Sparkle: bắt đầu cài \(item.displayVersionString) (build \(item.versionString))")
        watchForInstall(deadline: Date().addingTimeInterval(120))
    }

    // MARK: - SPUStandardUserDriverDelegate

    /// GTV là app nền: thông báo bản mới theo kiểu "nhắc nhẹ", không giật focus khi người dùng đang gõ.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                              andInImmediateFocus immediateFocus: Bool) -> Bool {
        true
    }
}
