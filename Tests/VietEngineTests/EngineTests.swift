import XCTest
@testable import VietEngine

/// Mô phỏng một ô nhập liệu: áp dụng các Action của engine lên văn bản.
private func type(_ keys: String, _ options: EngineOptions = EngineOptions()) -> String {
    let engine = Engine(options: options)
    var text = ""
    func apply(_ action: Action, key: Character?) {
        switch action {
        case .passThrough:
            if let key { text.append(key) }
        case let .replace(old, new):
            XCTAssertTrue(text.hasSuffix(old), "'\(text)' không kết thúc bằng '\(old)'")
            text = String(text.dropLast(old.count)) + new
        }
    }
    for k in keys {
        if k == "<" {           // "<" = Backspace
            if engine.isEmpty { if !text.isEmpty { text.removeLast() } ; continue }
            let a = engine.backspace()
            if case .passThrough = a { text.removeLast() } else { apply(a, key: nil) }
            continue
        }
        if let a = engine.process(k) {
            apply(a, key: k)
        } else {
            apply(engine.finishWord().action, key: nil)
            text.append(k)
        }
    }
    apply(engine.finishWord().action, key: nil)
    return text
}

final class TelexTests: XCTestCase {
    func testBasicWords() {
        let cases: [(String, String)] = [
            ("vieetj", "việt"), ("Vieetj Nam", "Việt Nam"), ("tieengs", "tiếng"),
            ("dduwowngf", "đường"), ("nguwowif", "người"), ("nguoiwf", "người"),
            ("truowngf", "trường"), ("thuowr", "thuở"), ("huow", "huơ"),
            ("quas", "quá"), ("gif", "gì"), ("giuwx", "giữ"), ("gias", "giá"),
            ("khuyeenx", "khuyễn"), ("muaw", "mưa"), ("hoawcj", "hoặc"),
            ("tooi", "tôi"), ("dd", "đ"), ("DDaij", "Đại"), ("VIEETJ", "VIỆT"),
            ("khuyr", "khủy"), ("khuyur", "khuỷu"), ("hoaij", "hoại"),
            ("nghieengs", "nghiếng"), ("xooong", "xoong"), ("uw", "ư"), ("w", "ư"),
            ("tw", "tư"), ("ddi", "đi"), ("cuwus", "cứu"), ("ruouwj", "rượu"),
            ("tieesng", "tiếng"), ("chuyeenj", "chuyện"), ("ddeemf", "đềm"),
            ("hoaf", "hòa"), ("thuys", "thúy"), ("khoer", "khỏe"), ("hoanf", "hoàn"),
            ("giowf", "giờ"), ("cos", "có"), ("nuwax", "nữa"), ("ddoongf", "đồng"),
        ]
        for (k, v) in cases { XCTAssertEqual(type(k), v, k) }
    }

    func testModernToneStyle() {
        let o = EngineOptions(modernToneStyle: true)
        XCTAssertEqual(type("hoaf", o), "hoà")
        XCTAssertEqual(type("thuys", o), "thuý")
        XCTAssertEqual(type("khoer", o), "khoẻ")
        XCTAssertEqual(type("khuyr", o), "khuỷ")
        XCTAssertEqual(type("hoanf", o), "hoàn")
        XCTAssertEqual(type("hoaf<", o), "ho")
    }

    func testUndo() {
        XCTAssertEqual(type("ass"), "as")
        XCTAssertEqual(type("lass"), "las")
        XCTAssertEqual(type("aa "), "â ")
        XCTAssertEqual(type("aw "), "ă ")
        XCTAssertEqual(type("aab"), "aab")    // "âb" không phải tiếng Việt
        XCTAssertEqual(type("aaa"), "aa")
        XCTAssertEqual(type("ddd"), "dd")
        XCTAssertEqual(type("ww"), "w")
        XCTAssertEqual(type("aww"), "aw")
        XCTAssertEqual(type("asz"), "a")
    }

    func testEnglishRestore() {
        for w in ["windows", "facebook", "text", "users", "string", "they", "the", "class",
                  "google", "with", "Windows", "express", "dead", "banana", "chrome"] {
            XCTAssertEqual(type(w), w, w)
        }
        XCTAssertEqual(type("text", EngineOptions(autoRestore: false)) != "text", true)
    }

    func testSimpleTelex() {
        let o = EngineOptions(method: .simpleTelex)
        XCTAssertEqual(type("w", o), "w")
        XCTAssertEqual(type("uw", o), "ư")
        XCTAssertEqual(type("nguwowif", o), "người")
        XCTAssertEqual(type("a[0]", o), "a[0]")
    }

    func testBrackets() {
        XCTAssertEqual(type("t]"), "tư")
        XCTAssertEqual(type("m["), "mơ")
    }

    func testBackspace() {
        XCTAssertEqual(type("hoaf<"), "hò")
        XCTAssertEqual(type("vieetj<<"), "vi")
        XCTAssertEqual(type("ass<s"), "á")
        XCTAssertEqual(type("hoanf<"), "hòa")
    }

    func testSentence() {
        XCTAssertEqual(type("Tooi yeeu tieengs Vieetj, ddepj lawms!"), "Tôi yêu tiếng Việt, đẹp lắm!")
    }
}

final class VNITests: XCTestCase {
    let o = EngineOptions(method: .vni)
    func testBasic() {
        XCTAssertEqual(type("vie65t", o), "việt")
        XCTAssertEqual(type("vie6t5", o), "việt")
        XCTAssertEqual(type("d9uo7ng2", o), "đường")
        XCTAssertEqual(type("nguo7i2", o), "người")
        XCTAssertEqual(type("a11", o), "a1")
        XCTAssertEqual(type("ho8c5", o), "ho8c5")
        XCTAssertEqual(type("hoa8c5", o), "hoặc")
        XCTAssertEqual(type("mu7a", o), "mưa")
        XCTAssertEqual(type("123 abc", o), "123 abc")
        XCTAssertEqual(type("D9a5i", o), "Đại")
    }
}

final class CharsetTests: XCTestCase {
    func testCombining() {
        let s = type("vieetj", EngineOptions(charset: .unicodeCombining))
        XCTAssertEqual(Array(s.unicodeScalars).map(\.value), [0x76, 0x69, 0xEA, 0x323, 0x74])
        XCTAssertEqual(s.precomposedStringWithCanonicalMapping, "việt")
    }

    func testTCVN3() {
        let o = EngineOptions(charset: .tcvn3)
        XCTAssertEqual(type("vieetj", o).unicodeScalars.map(\.value), [0x76, 0x69, 0xD6, 0x74])
        XCTAssertEqual(type("dd", o).unicodeScalars.map(\.value), [0xAE])
        XCTAssertEqual(type("DD", o).unicodeScalars.map(\.value), [0xA7])
        XCTAssertEqual(type("Awn", o).unicodeScalars.map(\.value), [0xA1, 0x6E])
        XCTAssertEqual(type("Aw", o).unicodeScalars.map(\.value), [0xA1])
        XCTAssertEqual(type("ddwowngf", o).unicodeScalars.map(\.value), [0xAE, 0xAD, 0xEA, 0x6E, 0x67])
    }
}

final class SeedTests: XCTestCase {
    /// Nạp `screen` như từ đang có trên màn hình rồi gõ tiếp `keys`.
    private func cont(_ screen: String, _ keys: String, _ o: EngineOptions = EngineOptions()) -> String {
        let e = Engine(options: o)
        var text = screen
        if !e.seed(screen) { return "seed failed" }
        for k in keys {
            switch e.process(k) {
            case .passThrough?: text.append(k)
            case let .replace(old, new)?:
                XCTAssertTrue(text.hasSuffix(old))
                text = String(text.dropLast(old.count)) + new
            case nil: text.append(k)
            }
        }
        return text
    }

    func testSeedContinue() {
        XCTAssertEqual(cont("o", "o"), "ô")          // Cmd+A, xoá, gõ lại "oo"
        XCTAssertEqual(cont("tiên", "s"), "tiến")
        XCTAssertEqual(cont("Viêt", "j"), "Việt")
        XCTAssertEqual(cont("ngươi", "f"), "người")
        XCTAssertEqual(cont("đươ", "ngf"), "đường")
        XCTAssertEqual(cont("thế", "f"), "thề")
    }

    func testSeedRejects() {
        XCTAssertFalse(Engine().seed("ab1"))
        XCTAssertFalse(Engine().seed("áà"))          // hai dấu thanh
        XCTAssertFalse(Engine(options: EngineOptions(charset: .tcvn3)).seed("tiên"))
    }
}
