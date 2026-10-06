import AppKit
import Carbon
import InputMethodKit

/// Chế độ Tiếng Việt / Tiếng Anh của GTV.
///
/// Đây là 2 input mode của cùng bộ gõ GTV ("<id>.vi", "<id>.en"). Chuyển chế độ bằng
/// `selectMode` trên ô nhập liệu đang dùng (API chính thức của InputMethodKit): bộ gõ không bị gỡ ra
/// hay gắn lại, nên chuyển tức thì, không nháy cửa sổ, và ⌘⇧ luôn do bộ gõ bắt được.
///
/// Ứng dụng loại trừ: khi GTV được gắn vào ô nhập liệu của ứng dụng trong danh sách thì chuyển sang
/// tiếng Anh; khi sang ứng dụng khác thì khôi phục tiếng Việt nếu trước đó đang gõ tiếng Việt.
final class Modes {
    static let shared = Modes()

    private(set) var vietnamese: Bool
    /// Đang ở ứng dụng loại trừ và trước đó đang gõ tiếng Việt.
    private var restoreVietnamese = false
    private weak var client: AnyObject?
    private var clientBundleID = ""
    /// GTV có đang được chọn không, bỏ qua lần đổi sang ABC do màn hình khoá (để khôi phục khi mở khoá).
    private var gtvInUse = InputSources.isGTVSelected
    /// Máy đang khoá màn hình hoặc đang ngủ: không coi các lần đổi bộ gõ lúc này là do người dùng.
    private var suspended = false
    /// Đổi sang bộ gõ khác chỉ được ghi nhận sau một lúc: khi gập máy, macOS có thể chuyển sang ABC
    /// trước khi kịp báo khoá/ngủ.
    private var pendingLeaveGTV: DispatchWorkItem?
    /// Hạn chờ màn hình hết khoá (đang chờ nếu khác nil).
    private var unlockDeadline: Date?

    private init() {
        vietnamese = InputSources.currentID != InputSources.englishID
        NotificationCenter.default.addObserver(forName: .gtvExcludedAppsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.exclusionChanged()
        }
        // macOS không phải lúc nào cũng báo cho bộ gõ (setValue) khi đổi chế độ, vd. khi ứng dụng đang
        // dùng không có ô nhập liệu nào đang focus: nghe thêm thông báo đổi bộ gõ của toàn hệ thống.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { [weak self] _ in
            self?.systemInputSourceChanged()
        }
        // Màn hình khoá luôn chuyển sang ABC để gõ mật khẩu, và macOS thường không trả lại bộ gõ bên
        // thứ ba khi mở khoá: tự chọn lại GTV.
        // Gập máy / máy ngủ cũng vậy (khi thức dậy màn hình thường bị khoá).
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.suspend("khoá màn hình")
        }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.resume("mở khoá")
        }
        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            wnc.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in
                self?.suspend(n.name.rawValue)
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            wnc.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in
                self?.resume(n.name.rawValue)
            }
        }
    }

    private func suspend(_ reason: String) {
        DebugLog.write("tạm dừng theo dõi (\(reason)), gtvInUse=\(gtvInUse), hiện tại=\(InputSources.currentID ?? "-")")
        suspended = true
        pendingLeaveGTV?.cancel()
        pendingLeaveGTV = nil
    }

    /// Thức dậy / mở khoá. Thông báo "mở khoá" có thể đến trước khi hệ thống kịp tắt cờ "màn hình
    /// khoá" (thấy khi gập máy rồi mở lại), nên nếu còn khoá thì kiểm tra lại mỗi 0,5 giây, tối đa
    /// 2 phút (đủ thời gian nhập mật khẩu).
    private func resume(_ reason: String) {
        let locked = Self.isScreenLocked
        DebugLog.write("tiếp tục (\(reason)), màn hình khoá=\(locked), gtvInUse=\(gtvInUse), hiện tại=\(InputSources.currentID ?? "-")")
        if locked {
            let startPolling = unlockDeadline == nil
            unlockDeadline = Date().addingTimeInterval(120)
            if startPolling { pollUnlock() }
            return
        }
        unlockDeadline = nil
        unlocked()
    }

    private func pollUnlock() {
        guard let deadline = unlockDeadline else { return }
        if !Self.isScreenLocked {
            unlockDeadline = nil
            DebugLog.write("màn hình đã hết khoá")
            unlocked()
        } else if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.pollUnlock() }
        } else {
            unlockDeadline = nil
        }
    }

    private func unlocked() {
        suspended = false
        for delay in [0.0, 0.5, 1.0, 2.0, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.restoreGTV() }
        }
    }

    private func restoreGTV() {
        guard gtvInUse, !suspended, !Self.isScreenLocked, !InputSources.isGTVSelected else { return }
        DebugLog.write("khôi phục GTV (\(vietnamese ? "vi" : "en")), đang ở \(InputSources.currentID ?? "-")")
        InputSources.selectMode(vietnamese ? InputSources.vietnameseID : InputSources.englishID)
    }

    private static var isScreenLocked: Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (info["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }


    private func systemInputSourceChanged() {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? clientBundleID
        DebugLog.write("bộ gõ đổi -> \(InputSources.currentID ?? "-"), front=\(front), tạm dừng=\(suspended)")
        if !suspended && front != "com.apple.loginwindow" && !Self.isScreenLocked {
            pendingLeaveGTV?.cancel()
            pendingLeaveGTV = nil
            if InputSources.isGTVSelected {
                gtvInUse = true
            } else if gtvInUse {
                // Người dùng tự chọn bộ gõ khác? Chỉ tin sau 3 giây không có khoá/ngủ.
                let work = DispatchWorkItem { [weak self] in
                    guard let self, !self.suspended, !InputSources.isGTVSelected else { return }
                    self.gtvInUse = false
                    DebugLog.write("ghi nhận: người dùng đã rời GTV")
                }
                pendingLeaveGTV = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
            }
        }
        guard InputSources.isGTVSelected, let id = InputSources.currentID else { return }
        guard id == InputSources.vietnameseID || id == InputSources.englishID else {
            syncSystemMode()   // bộ gõ "cha" được chọn: chọn lại chế độ
            return
        }
        if id == InputSources.vietnameseID && isExcluded(front) {
            restoreVietnamese = true
            vietnamese = false
            syncSystemMode()
            return
        }
        set(id == InputSources.vietnameseID, updateSystem: false)
    }

    private func isExcluded(_ bundleID: String) -> Bool {
        Settings.shared.excludedApps.contains(bundleID)
    }

    /// GTV được gắn vào một ô nhập liệu.
    func clientActivated(_ client: Client, bundleID: String) {
        self.client = client
        clientBundleID = bundleID
        if isExcluded(bundleID) {
            if vietnamese {
                restoreVietnamese = true
                set(false)
            }
        } else if restoreVietnamese {
            restoreVietnamese = false
            set(true)
        }
        syncSystemMode()
    }

    /// Khi chuyển ứng dụng, macOS có lúc chọn bộ gõ GTV "cha" thay vì một chế độ (biểu tượng không
    /// còn cho biết V hay E), hoặc chọn chế độ khác với trạng thái của GTV: chọn lại cho khớp.
    /// Chạy sau, ngoài lúc macOS đang báo sự kiện cho bộ gõ.
    private func syncSystemMode() {
        DispatchQueue.main.async { [self] in
            let mode = vietnamese ? InputSources.vietnameseID : InputSources.englishID
            if InputSources.isGTVSelected && InputSources.currentID != mode {
                InputSources.selectMode(mode)
            }
        }
    }

    /// macOS báo đổi chế độ (menu bộ gõ, phím 🌐, Ctrl+Space, hoặc do chính GTV gọi `selectMode`).
    func modeSelected(_ modeID: String) {
        let on = modeID != InputSources.englishID
        if on && isExcluded(clientBundleID) {
            // Ứng dụng loại trừ không gõ tiếng Việt: trả về tiếng Anh.
            restoreVietnamese = true
            vietnamese = false
            syncSystemMode()
            return
        }
        set(on, updateSystem: false)
    }

    /// Người dùng chuyển Anh/Việt (phím tắt, menu).
    func toggle() {
        if !vietnamese && isExcluded(clientBundleID) { return }
        if Settings.shared.playSwitchSound { NSSound.beep() }
        DebugLog.write("toggle -> \(vietnamese ? "en" : "vi")")
        set(!vietnamese)
    }

    /// Kiểm tra lại sau một lúc: nếu hệ thống vẫn chưa ở đúng chế độ thì chọn lại.
    private func verifySystemMode(retries: Int, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            let mode = vietnamese ? InputSources.vietnameseID : InputSources.englishID
            guard InputSources.isGTVSelected, InputSources.currentID != mode else {
                DebugLog.write("kiểm tra sau \(delay)s: khớp (\(InputSources.currentID ?? "-"))")
                return
            }
            DebugLog.write("kiểm tra sau \(delay)s: CHƯA khớp (\(InputSources.currentID ?? "-")), chọn lại \(mode)")
            InputSources.selectMode(mode)
            if retries > 0 { verifySystemMode(retries: retries - 1, delay: 0.3) }
        }
    }

    /// Người dùng thêm/bỏ ứng dụng khỏi danh sách loại trừ.
    private func exclusionChanged() {
        guard !clientBundleID.isEmpty else { return }
        if isExcluded(clientBundleID) {
            if vietnamese {
                restoreVietnamese = true
                set(false)
            }
        } else if !vietnamese {
            // Vừa bỏ loại trừ ứng dụng đang dùng: người dùng muốn gõ tiếng Việt ở đây.
            restoreVietnamese = false
            set(true)
        }
    }

    private func set(_ on: Bool, updateSystem: Bool = true) {
        guard on != vietnamese else { return }
        vietnamese = on
        if updateSystem {
            syncSystemMode()
            verifySystemMode(retries: 1, delay: 0.3)
        }
        NotificationCenter.default.post(name: .gtvSettingsChanged, object: nil)
    }
}
