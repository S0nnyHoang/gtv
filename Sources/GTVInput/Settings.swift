import AppKit
import VietEngine

extension Notification.Name {
    static let gtvSettingsChanged = Notification.Name("GTVSettingsChanged")
    static let gtvExcludedAppsChanged = Notification.Name("GTVExcludedAppsChanged")
}

/// Phím tắt chuyển Anh/Việt (nhấn rồi nhả tổ hợp phím bổ trợ).
enum ToggleHotkey: Int, CaseIterable {
    case none = 0, controlShift, optionShift, commandShift

    /// Thứ tự hiển thị trong menu.
    static let menuOrder: [ToggleHotkey] = [.commandShift, .controlShift, .optionShift, .none]

    var flags: NSEvent.ModifierFlags? {
        switch self {
        case .none: return nil
        case .controlShift: return [.control, .shift]
        case .optionShift: return [.option, .shift]
        case .commandShift: return [.command, .shift]
        }
    }

    var title: String {
        switch self {
        case .none: return "Không dùng"
        case .controlShift: return "⌃⇧  Control + Shift"
        case .optionShift: return "⌥⇧  Option + Shift"
        case .commandShift: return "⌘⇧  Command + Shift"
        }
    }
}

/// Cài đặt dùng chung cho mọi ô nhập liệu (lưu trong UserDefaults của bộ gõ).
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    /// Terminal: không thay được chữ đã nhập, mặc định gõ ở chế độ terminal (gửi xoá lùi + chữ mới,
    /// xem `Session`). Trước 1.11.2 các ứng dụng này mặc định dùng gạch chân.
    static let defaultTerminalApps = [
        "com.apple.Terminal", "com.googlecode.iterm2", "net.kovidgoyal.kitty", "io.alacritty",
        "com.github.wez.wezterm", "dev.warp.Warp-Stable", "com.mitchellh.ghostty", "co.zeit.hyper",
        "org.tabby", "com.raphaelamorim.rio",
    ]

    private(set) var options: EngineOptions
    var alwaysMarked: Bool {
        didSet { defaults.set(alwaysMarked, forKey: "alwaysMarked") }
    }
    var hotkey: ToggleHotkey {
        didSet { defaults.set(hotkey.rawValue, forKey: "hotkey"); changed() }
    }
    private(set) var markedApps: Set<String>
    private(set) var terminalApps: Set<String>
    /// Phát âm báo của hệ thống khi người dùng chuyển Anh/Việt (phím tắt, menu).
    var playSwitchSound: Bool {
        didSet { defaults.set(playSwitchSound, forKey: "playSwitchSound") }
    }
    /// GTV.app nằm trong "Mở khi đăng nhập": khi đăng nhập tự chọn GTV nếu đang ở bộ gõ khác.
    var selectAtLogin: Bool {
        didSet {
            defaults.set(selectAtLogin, forKey: "selectAtLogin")
            defaults.synchronize()
            Settings.runLauncher(["--sync-login-item"])
        }
    }

    /// Chạy GTV.app (launcher) với tham số — việc đăng ký "Mở khi đăng nhập" phải do chính GTV.app làm.
    /// Vị trí GTV.app. Ưu tiên bản trong Applications (máy phát triển còn có các bản build khác cùng
    /// bundle ID).
    static func launcherURL() -> URL? {
        let fm = FileManager.default
        let candidates = ["/Applications/GTV.app", fm.homeDirectoryForCurrentUser.path + "/Applications/GTV.app"]
            .map { URL(fileURLWithPath: $0) }.filter { fm.fileExists(atPath: $0.path) }
        return candidates.first ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.gtv.GTV")
    }

    static func runLauncher(_ arguments: [String]) {
        guard let app = launcherURL(), let exe = Bundle(url: app)?.executableURL else { return }
        let p = Process()
        p.executableURL = exe
        p.arguments = arguments
        try? p.run()
    }

    /// Biểu tượng V/E riêng của GTV (mặc định ẩn: menu bộ gõ của macOS đã có đủ).
    var showStatusIcon: Bool {
        didSet { defaults.set(showStatusIcon, forKey: "showStatusIcon"); changed() }
    }
    /// Ứng dụng không gõ tiếng Việt: GTV tự chuyển sang chế độ tiếng Anh (xem Modes).
    private(set) var excludedApps: Set<String>

    private init() {
        defaults.register(defaults: [
            "method": InputMethod.telex.rawValue,
            "charset": Charset.unicode.rawValue,
            "modernToneStyle": false,
            "autoRestore": true,
            "alwaysMarked": false,
            "hotkey": ToggleHotkey.commandShift.rawValue,
            "markedApps": [String](),
            "terminalApps": Settings.defaultTerminalApps,
            "excludedApps": [String](),
            "showStatusIcon": false,
            "playSwitchSound": true,
            "selectAtLogin": true,
        ])
        alwaysMarked = defaults.bool(forKey: "alwaysMarked")
        hotkey = ToggleHotkey(rawValue: defaults.integer(forKey: "hotkey")) ?? .commandShift
        markedApps = Set(defaults.stringArray(forKey: "markedApps") ?? [])
        terminalApps = Set(defaults.stringArray(forKey: "terminalApps") ?? [])
        // Bản cũ lưu cả danh sách gạch chân mặc định (các terminal) khi người dùng bật/tắt một ứng dụng:
        // bỏ các terminal đó ra để chúng dùng chế độ terminal mới (một lần).
        if !defaults.bool(forKey: "migratedTerminalMode") {
            defaults.set(true, forKey: "migratedTerminalMode")
            if defaults.object(forKey: "markedApps") != nil {
                markedApps.subtract(Settings.defaultTerminalApps)
                defaults.set(markedApps.sorted(), forKey: "markedApps")
            }
        }
        showStatusIcon = defaults.bool(forKey: "showStatusIcon")
        playSwitchSound = defaults.bool(forKey: "playSwitchSound")
        selectAtLogin = defaults.bool(forKey: "selectAtLogin")
        excludedApps = Set(defaults.stringArray(forKey: "excludedApps") ?? [])
        options = EngineOptions(
            method: InputMethod(rawValue: defaults.integer(forKey: "method")) ?? .telex,
            charset: Charset(rawValue: defaults.integer(forKey: "charset")) ?? .unicode,
            modernToneStyle: defaults.bool(forKey: "modernToneStyle"),
            autoRestore: defaults.bool(forKey: "autoRestore"))
    }

    private func changed() {
        NotificationCenter.default.post(name: .gtvSettingsChanged, object: nil)
    }

    func update(_ change: (inout EngineOptions) -> Void) {
        change(&options)
        defaults.set(options.method.rawValue, forKey: "method")
        defaults.set(options.charset.rawValue, forKey: "charset")
        defaults.set(options.modernToneStyle, forKey: "modernToneStyle")
        defaults.set(options.autoRestore, forKey: "autoRestore")
    }

    func useMarked(for bundleID: String) -> Bool {
        alwaysMarked || markedApps.contains(bundleID)
    }

    func toggleMarked(for bundleID: String) {
        guard !bundleID.isEmpty else { return }
        if markedApps.contains(bundleID) { markedApps.remove(bundleID) } else { markedApps.insert(bundleID) }
        defaults.set(markedApps.sorted(), forKey: "markedApps")
    }

    /// Gạch chân (nếu bật) được ưu tiên hơn chế độ terminal.
    func useTerminalMode(for bundleID: String) -> Bool {
        terminalApps.contains(bundleID)
    }

    func toggleTerminalMode(for bundleID: String) {
        guard !bundleID.isEmpty else { return }
        if terminalApps.contains(bundleID) { terminalApps.remove(bundleID) } else { terminalApps.insert(bundleID) }
        defaults.set(terminalApps.sorted(), forKey: "terminalApps")
    }

    func setExcluded(_ bundleIDs: [String], _ excluded: Bool) {
        for id in bundleIDs where !id.isEmpty {
            if excluded { excludedApps.insert(id) } else { excludedApps.remove(id) }
        }
        defaults.set(excludedApps.sorted(), forKey: "excludedApps")
        NotificationCenter.default.post(name: .gtvExcludedAppsChanged, object: nil)
    }
}
