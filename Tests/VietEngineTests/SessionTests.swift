import XCTest
@testable import VietEngine

/// Ô nhập liệu giả, mô phỏng hành vi của ứng dụng thật.
private final class Field: TextClient {
    var units: [UInt16] = []          // văn bản (UTF-16)
    var sel = (location: 0, length: 0)
    var readable = true               // ứng dụng có cho đọc văn bản không
    var suggestions: [String] = []    // gợi ý tự động kiểu thanh địa chỉ

    let session = Session()
    var options = EngineOptions()

    var text: String { String(decoding: units, as: UTF16.self) }

    // MARK: TextClient
    func selectedRange() -> (location: Int, length: Int)? { sel }
    func text(location: Int, length: Int) -> String? {
        guard readable, location >= 0, location + length <= units.count else { return nil }
        return String(decoding: units[location..<location + length], as: UTF16.self)
    }
    func replaceText(location: Int, length: Int, with s: String) {
        units.replaceSubrange(location..<location + length, with: Array(s.utf16))
        sel = (location + s.utf16.count, 0)
        autocomplete()
    }
    func setMarkedText(_ text: String) {}
    func insertText(_ text: String) { replaceText(location: sel.location, length: sel.length, with: text) }

    // MARK: Thao tác của người dùng
    func type(_ keys: String) {
        for k in keys {
            if !session.handle(.char(k), self, options: options, forceMarked: false) {
                insertText(String(k))        // ứng dụng tự xử lý phím
            }
        }
    }

    func backspace() {
        if session.handle(.backspace, self, options: options, forceMarked: false) { return }
        if sel.length > 0 {
            units.removeSubrange(sel.location..<sel.location + sel.length)
        } else if sel.location > 0 {
            let before = String(decoding: units[0..<sel.location], as: UTF16.self)
            let n = before.last!.utf16.count
            units.removeSubrange(sel.location - n..<sel.location)
            sel.location -= n
        }
        sel.length = 0
    }

    /// Cmd+A — ứng dụng tự xử lý, bộ gõ không thấy.
    func selectAll() { sel = (0, units.count) }

    private func autocomplete() {
        let t = text
        guard sel.location == units.count, !t.isEmpty,
              let s = suggestions.first(where: { $0.hasPrefix(t) && $0 != t }) else { return }
        let rest = Array(s.utf16.dropFirst(units.count))
        units += rest
        sel.length = rest.count
    }
}

final class SessionTests: XCTestCase {
    func testTypingThroughSession() {
        let f = Field()
        f.type("Tooi yeeu tieengs Vieetj, ddepj lawms!")
        XCTAssertEqual(f.text, "Tôi yêu tiếng Việt, đẹp lắm!")
    }

    /// Gõ, Cmd+A, Delete, gõ lại — bộ gõ không thấy Cmd+A.
    func testSelectAllDeleteRetype() {
        let cases: [(String, String, String)] = [
            ("uw", "uw", "ư"), ("ow", "ow", "ơ"), ("ee", "ee", "ê"), ("w", "w", "ư"),
            ("oo thees", "oo", "ô"), ("dd", "dd", "đ"), ("vieetj", "aa", "â"),
        ]
        for readable in [true, false] {
            for (first, again, expected) in cases {
                let f = Field()
                f.readable = readable
                f.type(first)
                f.selectAll()
                f.backspace()
                f.type(again)
                XCTAssertEqual(f.text, expected, "\(first) -> \(again), readable=\(readable)")
            }
        }
    }

    /// Cmd+A rồi gõ đè luôn (không xoá).
    func testSelectAllOverwrite() {
        for readable in [true, false] {
            let f = Field()
            f.readable = readable
            f.type("ow")
            f.selectAll()
            f.type("uw")
            XCTAssertEqual(f.text, "ư", "readable=\(readable)")
        }
    }

    /// Thanh địa chỉ có gợi ý tự động đang bôi đen sau con trỏ.
    func testAutocomplete() {
        let f = Field()
        f.suggestions = ["dantri.com.vn", "oops.com", "tuoitre.vn"]
        f.type("dd")
        XCTAssertEqual(f.text, "đ")
        let g = Field()
        g.suggestions = f.suggestions
        g.type("oo")
        XCTAssertEqual(g.text, "ô")
        let h = Field()
        h.suggestions = f.suggestions
        h.type("tuoi")
        XCTAssertEqual(h.text, "tuoitre.vn")
        h.type("o")                          // gợi ý "tre.vn" đang bôi đen bị thay luôn
        XCTAssertEqual(h.text, "tuôi")
    }

    /// Backspace khi có gợi ý tự động: chỉ xoá gợi ý, từ đang gõ giữ nguyên.
    func testBackspaceOnSuggestion() {
        let f = Field()
        f.suggestions = ["vietnamnet.vn"]
        f.type("vie")
        XCTAssertEqual(f.text, "vietnamnet.vn")
        f.backspace()
        XCTAssertEqual(f.text, "vie")
        f.type("e")
        XCTAssertEqual(f.text, "viê")
    }

    /// Văn bản đổi ngoài tầm bộ gõ (Cmd+Z, dán...) ở giữa từ.
    func testExternalEdit() {
        let f = Field()
        f.type("tieng")
        f.units = Array("xin chao".utf16)
        f.sel = (8, 0)
        f.type("f")
        XCTAssertEqual(f.text, "xin chào")
    }

    func testBackspaceInWord() {
        let f = Field()
        f.type("vieetj")
        f.backspace()
        f.backspace()
        XCTAssertEqual(f.text, "vi")
        f.type("eets")
        XCTAssertEqual(f.text, "viết")
    }
}
