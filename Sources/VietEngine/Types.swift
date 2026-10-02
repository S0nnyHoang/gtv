public enum InputMethod: Int, CaseIterable, Sendable {
    case telex = 0
    case vni = 1
    case simpleTelex = 2
}

public enum Charset: Int, CaseIterable, Sendable {
    /// Unicode dựng sẵn (NFC).
    case unicode = 0
    /// Unicode tổ hợp: chữ có mũ/móc dựng sẵn + dấu thanh tổ hợp (U+0300...).
    case unicodeCombining = 1
    /// TCVN3 (ABC), xuất ra dưới dạng các ký tự Latin-1 tương ứng với mã byte.
    case tcvn3 = 2
}

public struct EngineOptions: Equatable, Sendable {
    public var method: InputMethod
    public var charset: Charset
    /// true: "hoà, thuý" (kiểu mới); false: "hòa, thúy" (kiểu cũ).
    public var modernToneStyle: Bool
    /// Tự khôi phục phím đã gõ khi từ không phải tiếng Việt (gõ tiếng Anh không cần tắt bộ gõ).
    public var autoRestore: Bool

    public init(method: InputMethod = .telex, charset: Charset = .unicode,
                modernToneStyle: Bool = false, autoRestore: Bool = true) {
        self.method = method
        self.charset = charset
        self.modernToneStyle = modernToneStyle
        self.autoRestore = autoRestore
    }
}

public enum Action: Equatable, Sendable {
    /// Để ứng dụng tự xử lý phím như bình thường (văn bản trên màn hình khớp với trạng thái bộ gõ).
    case passThrough
    /// Thay `old` (đang nằm ngay trước con trỏ) bằng `new`.
    case replace(old: String, new: String)
}

enum Mark: UInt8 {
    case none, hat, breve, horn, stroke
}

enum Tone: Int {
    case none = 0, acute, grave, hook, tilde, dot
}

struct VChar {
    var base: UInt8          // ASCII thường (a-z) hoặc ký tự literal
    var mark: Mark = .none
    var upper = false
    var fromW = false        // "ư" sinh ra từ phím w đứng riêng (Telex)

    @inline(__always) var isVowel: Bool { Ch.isVowel(base) }
}

enum Ch {
    static let a = UInt8(ascii: "a"), d = UInt8(ascii: "d"), e = UInt8(ascii: "e")
    static let g = UInt8(ascii: "g"), i = UInt8(ascii: "i"), o = UInt8(ascii: "o")
    static let q = UInt8(ascii: "q"), u = UInt8(ascii: "u"), y = UInt8(ascii: "y")
    static let w = UInt8(ascii: "w")

    @inline(__always) static func isVowel(_ c: UInt8) -> Bool {
        c == a || c == e || c == i || c == o || c == u || c == y
    }
}
