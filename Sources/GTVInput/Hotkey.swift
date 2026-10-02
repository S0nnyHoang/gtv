import CoreGraphics
import Foundation

enum Hotkey {
    /// Tổ hợp phím bổ trợ được nhấn từ thời điểm `armed` (systemUptime) có phải là nhấn-rồi-nhả "trơn"
    /// không: không có phím thường hay cú click chuột nào xen vào (vd. ⌘⇧Z, ⌘⇧4, ⌘⇧+click).
    /// Hỏi trực tiếp hệ thống nên đúng cả với phím tắt mà ứng dụng xử lý trước khi tới bộ gõ.
    static func isCleanTap(since armed: TimeInterval) -> Bool {
        let held = ProcessInfo.processInfo.systemUptime - armed
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return types.allSatisfy {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) >= held
        }
    }
}
