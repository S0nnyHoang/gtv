import Cocoa
import InputMethodKit
import VietEngine

typealias Client = IMKTextInput & NSObjectProtocol

private let notFound = NSRange(location: NSNotFound, length: 0)

/// Chuyển IMKTextInput thành TextClient cho Session.
private final class ClientAdapter: TextClient {
    var client: Client?

    func selectedRange() -> (location: Int, length: Int)? {
        guard let r = client?.selectedRange(), r.location != NSNotFound else { return nil }
        return (r.location, r.length)
    }

    func text(location: Int, length: Int) -> String? {
        client?.attributedSubstring(from: NSRange(location: location, length: length))?.string
    }

    func replaceText(location: Int, length: Int, with text: String) {
        client?.insertText(text, replacementRange: NSRange(location: location, length: length))
    }

    func setMarkedText(_ text: String) {
        client?.setMarkedText(text, selectionRange: NSRange(location: text.utf16.count, length: 0),
                              replacementRange: notFound)
    }

    func insertText(_ text: String) {
        client?.insertText(text, replacementRange: notFound)
    }

    func replaceViaMarkedText(location: Int, length: Int, with text: String) {
        client?.setMarkedText(text, selectionRange: NSRange(location: text.utf16.count, length: 0),
                              replacementRange: NSRange(location: location, length: length))
        client?.insertText(text, replacementRange: notFound)
    }
}

/// Một controller cho mỗi ô nhập liệu.
///
/// Cách hoạt động (chế độ mặc định — không gạch chân), chi tiết trong `Session`:
/// - Phím không cần biến đổi được trả lại cho ứng dụng xử lý như bình thường.
/// - Khi cần thêm dấu, bộ gõ thay đúng đoạn chữ trước con trỏ bằng
///   `insertText(_:replacementRange:)` thay vì gửi phím Backspace giả, nên vùng gợi ý tự động
///   đang bôi đen (thanh địa chỉ, ô tìm kiếm) cũng bị thay luôn — không còn lỗi "dđ", "oô".
/// - Bộ gõ nhớ vị trí bắt đầu của từ; nếu con trỏ không còn ở đúng chỗ (Cmd+A, Cmd+Z, chuột...)
///   thì bỏ từ cũ và đọc lại từ trên màn hình.
///
/// Terminal không thay được chữ đã nhập: gửi ký tự xoá lùi rồi chữ mới (chế độ terminal, xem `Session`).
/// Ứng dụng nào không hợp thì người dùng bật gạch chân (marked text) như bộ gõ thông thường.
@objc(GTVInputController)
final class GTVInputController: IMKInputController {
    private let session = Session()
    private let adapter = ClientAdapter()
    private var bundleID = ""
    private var hotkeyArmedAt: TimeInterval?
    /// Số phím bộ gõ đã nhận, và độ lệch so với bộ đếm phím của hệ thống (xem `missedKeys`).
    private var seenKeys = 0
    private var keyOffset: Int?
    private var lastKeyTime: TimeInterval?

    // MARK: - Vòng đời

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]).rawValue)
    }

    override func activateServer(_ sender: Any!) {
        session.reset()
        hotkeyArmedAt = nil
        guard let client = sender as? Client else { return }
        bundleID = client.bundleIdentifier() ?? ""
        Modes.shared.clientActivated(client, bundleID: bundleID)
        _ = QtDetector.isQt(bundleID)   // kiểm tra trước ở luồng nền, có kết quả trước khi cần
    }

    override func deactivateServer(_ sender: Any!) {
        commit(sender)
    }

    override func commitComposition(_ sender: Any!) {
        commit(sender)
    }

    /// macOS báo đổi chế độ Tiếng Việt / Tiếng Anh.
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        guard tag == Int(kTextServiceInputModePropertyTag), let mode = value as? String else {
            super.setValue(value, forTag: tag, client: sender)
            return
        }
        commit(sender)
        Modes.shared.modeSelected(mode)
    }

    private func commit(_ sender: Any?) {
        adapter.client = sender as? Client
        session.commit(adapter.client == nil ? nil : adapter)
        adapter.client = nil
    }

    // MARK: - Xử lý phím

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? Client else { return false }
        // Bộ gõ khởi động lại khi ô nhập liệu đang mở (vd. sau khi cập nhật): không có activateServer.
        if bundleID.isEmpty { bundleID = client.bundleIdentifier() ?? "" }
        let settings = Settings.shared
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])

        switch event.type {
        case .flagsChanged:
            // Phím tắt chuyển Anh/Việt: nhấn rồi nhả tổ hợp phím bổ trợ, không kèm phím nào khác.
            if let hotkey = settings.hotkey.flags {
                if flags == hotkey {
                    if hotkeyArmedAt == nil { hotkeyArmedAt = ProcessInfo.processInfo.systemUptime }
                } else if flags.isEmpty {
                    // Phím tắt như ⌘⇧Z được ứng dụng xử lý trước, bộ gõ không thấy phím Z:
                    // hỏi hệ thống xem có phím/click nào xen vào không.
                    if let armed = hotkeyArmedAt, Hotkey.isCleanTap(since: armed) {
                        commit(client)
                        // Chọn chế độ ngoài lúc đang xử lý sự kiện phím.
                        DispatchQueue.main.async { Modes.shared.toggle() }
                    }
                    hotkeyArmedAt = nil
                } else if !hotkey.isSuperset(of: flags) {
                    hotkeyArmedAt = nil
                }
            }
            return false
        case .keyDown:
            hotkeyArmedAt = nil
            if missedKeys(event), settings.useTerminalMode(for: bundleID) { session.reset() }
        default:                             // click chuột: con trỏ có thể đã đổi chỗ
            commit(client)
            return false
        }

        // Chế độ tiếng Anh, hoặc ứng dụng loại trừ: phím đi thẳng.
        guard Modes.shared.vietnamese, !settings.excludedApps.contains(bundleID) else {
            commit(client)
            return false
        }

        let key: Key
        if !flags.isDisjoint(with: [.command, .control, .option]) {
            key = .other
        } else if event.keyCode == 51 {      // Delete
            key = .backspace
        } else if let chars = event.characters, chars.count == 1, let ch = chars.first {
            key = .char(ch)
        } else {
            key = .other
        }

        adapter.client = client
        defer { adapter.client = nil }
        return session.handle(key, adapter, options: settings.options,
                              forceMarked: settings.useMarked(for: bundleID),
                              qtApp: QtDetector.isQt(bundleID),
                              terminal: settings.useTerminalMode(for: bundleID))
    }

    /// Có phím nào được nhấn mà bộ gõ không thấy kể từ phím trước không. Terminal.app tự gửi Delete,
    /// Ctrl+U, mũi tên… xuống shell, không qua bộ gõ; ở chế độ terminal không đọc được dòng lệnh để
    /// phát hiện, nên so bộ đếm phím của hệ thống với số phím bộ gõ đã nhận: lệch thêm nghĩa là có phím
    /// xen vào, bỏ từ đang gõ (gõ tiếp như từ mới) thay vì thay sai chữ.
    /// Bộ đếm không đồng bộ với lúc bộ gõ nhận phím: khi gõ nhanh nó có thể chưa tính phím này, hoặc đã
    /// tính cả phím nhấn sau. Chỉ so khi lần nhấn phím mới nhất của hệ thống chính là phím này.
    private func missedKeys(_ event: NSEvent) -> Bool {
        seenKeys += 1
        let gap = event.timestamp - (lastKeyTime ?? 0)
        lastKeyTime = event.timestamp
        // Thời điểm của lần nhấn phím mới nhất mà hệ thống đã đếm, so với phím này. Hai đồng hồ lệch nhau
        // vài ms nên cho phép sai số, nhưng không quá nửa khoảng cách tới phím trước.
        let d = ProcessInfo.processInfo.systemUptime
            - CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown) - event.timestamp
        let window = min(max(gap / 2, 0.003), 0.015)
        guard d > -window, d < 0.003 else { return false }
        let offset = Int(CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)) - seenKeys
        guard let last = keyOffset else { keyOffset = offset; return false }
        // Độ lệch thật chỉ tăng (có phím bộ gõ không thấy); đo ra nhỏ hơn là bộ đếm chưa kịp tính phím này.
        keyOffset = max(last, offset)
        return offset > last
    }

    // MARK: - Menu trong biểu tượng bộ gõ của macOS

    override func menu() -> NSMenu! {
        AppMenu.build(target: self, action: #selector(menuAction(_:)), appBundleID: bundleID, standalone: false)
    }

    @objc func menuAction(_ sender: Any?) {
        let item = (sender as? [String: Any])?[kIMKCommandMenuItemName] as? NSMenuItem
            ?? sender as? NSMenuItem
        guard let item else { return }
        AppMenu.perform(item, appBundleID: bundleID)
        session.reset()
    }
}
