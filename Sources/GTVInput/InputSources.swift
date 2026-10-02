import Carbon
import Foundation

/// Thao tác với danh sách bộ gõ của macOS (Text Input Sources).
enum InputSources {
    static let gtvID = Bundle.main.bundleIdentifier ?? "com.gtv.inputmethod.GTV"
    static let vietnameseID = gtvID + ".vi"
    static let englishID = gtvID + ".en"

    private static func string(_ src: TISInputSource, _ key: CFString) -> String? {
        guard let p = TISGetInputSourceProperty(src, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }

    /// ID bộ gõ hiện tại; với GTV là ID của chế độ (macOS có lúc trả về bộ gõ cha, chế độ nằm ở
    /// thuộc tính InputModeID).
    static var currentID: String? {
        guard let cur = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return string(cur, kTISPropertyInputModeID) ?? string(cur, kTISPropertyInputSourceID)
    }

    static var isGTVSelected: Bool { currentID?.hasPrefix(gtvID) ?? false }

    /// Chọn chế độ khi không có ô nhập liệu nào để gọi `selectMode` (dự phòng).
    static func selectMode(_ id: String) {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let src = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first
        else { return }
        TISSelectInputSource(src)
    }

    /// Chuyển về bàn phím tiếng Anh của macOS (ABC) — dùng khi thoát GTV.
    static func selectSystemKeyboard() {
        guard let src = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else { return }
        TISEnableInputSource(src)
        TISSelectInputSource(src)
    }
}
