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
    private var screenLocked = false

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
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenLocked = true
        }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenUnlocked()
        }
    }

    private func screenUnlocked() {
        screenLocked = false
        restoreAfterLock(retries: 3)
    }

    private func restoreAfterLock(retries: Int) {
        guard gtvInUse, !InputSources.isGTVSelected else { return }
        InputSources.selectMode(vietnamese ? InputSources.vietnameseID : InputSources.englishID)
        if retries > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.restoreAfterLock(retries: retries - 1)
            }
        }
    }

    private func systemInputSourceChanged() {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? clientBundleID
        if !screenLocked && front != "com.apple.loginwindow" {
            gtvInUse = InputSources.isGTVSelected   // người dùng tự đổi bộ gõ
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
