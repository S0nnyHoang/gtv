/// Bảng chữ cái, bảng mã và các quy tắc âm tiết tiếng Việt.
enum VTable {
    // Mỗi hàng: [không dấu, sắc, huyền, hỏi, ngã, nặng]
    private static let rows = [
        "aáàảãạ", "ăắằẳẵặ", "âấầẩẫậ",
        "eéèẻẽẹ", "êếềểễệ",
        "iíìỉĩị",
        "oóòỏõọ", "ôốồổỗộ", "ơớờởỡợ",
        "uúùủũụ", "ưứừửữự",
        "yýỳỷỹỵ",
    ]
    static let plainU = 9

    static let lower: [[Unicode.Scalar]] = rows.map { Array($0.unicodeScalars) }
    static let upper: [[Unicode.Scalar]] = rows.map { Array($0.uppercased().unicodeScalars) }

    /// Dấu thanh tổ hợp theo thứ tự Tone.
    static let combining: [UInt32] = [0, 0x0301, 0x0300, 0x0309, 0x0303, 0x0323]

    /// TCVN3 (ABC). Chữ hoa có dấu thanh dùng chung mã chữ thường (font .VnTimeH hiển thị hoa).
    static let tcvn3: [[UInt32]] = [
        [0x61, 0xB8, 0xB5, 0xB6, 0xB7, 0xB9],   // a
        [0xA8, 0xBE, 0xBB, 0xBC, 0xBD, 0xC6],   // ă
        [0xA9, 0xCA, 0xC7, 0xC8, 0xC9, 0xCB],   // â
        [0x65, 0xD0, 0xCC, 0xCE, 0xCF, 0xD1],   // e
        [0xAA, 0xD5, 0xD2, 0xD3, 0xD4, 0xD6],   // ê
        [0x69, 0xDD, 0xD7, 0xD8, 0xDC, 0xDE],   // i
        [0x6F, 0xE3, 0xDF, 0xE1, 0xE2, 0xE4],   // o
        [0xAB, 0xE8, 0xE5, 0xE6, 0xE7, 0xE9],   // ô
        [0xAC, 0xED, 0xEA, 0xEB, 0xEC, 0xEE],   // ơ
        [0x75, 0xF3, 0xEF, 0xF1, 0xF2, 0xF4],   // u
        [0xAD, 0xF8, 0xF5, 0xF6, 0xF7, 0xF9],   // ư
        [0x79, 0xFD, 0xFA, 0xFB, 0xFC, 0xFE],   // y
    ]
    static let tcvn3UpperPlain: [UInt32] = [0x41, 0xA1, 0xA2, 0x45, 0xA3, 0x49, 0x4F, 0xA4, 0xA5, 0x55, 0xA6, 0x59]

    /// Chữ Unicode dựng sẵn -> (chữ gốc + mũ/móc, thanh). Dùng để nạp lại từ có sẵn.
    static let decompose: [Character: (char: VChar, tone: Tone)] = {
        let bases: [(UInt8, Mark)] = [
            (Ch.a, .none), (Ch.a, .breve), (Ch.a, .hat), (Ch.e, .none), (Ch.e, .hat), (Ch.i, .none),
            (Ch.o, .none), (Ch.o, .hat), (Ch.o, .horn), (Ch.u, .none), (Ch.u, .horn), (Ch.y, .none),
        ]
        var map: [Character: (char: VChar, tone: Tone)] = [:]
        for (r, (base, mark)) in bases.enumerated() {
            for t in 0..<6 {
                map[Character(lower[r][t])] = (VChar(base: base, mark: mark), Tone(rawValue: t)!)
                map[Character(upper[r][t])] = (VChar(base: base, mark: mark, upper: true), Tone(rawValue: t)!)
            }
        }
        map["đ"] = (VChar(base: Ch.d, mark: .stroke), .none)
        map["Đ"] = (VChar(base: Ch.d, mark: .stroke, upper: true), .none)
        return map
    }()

    @inline(__always)
    static func row(_ base: UInt8, _ mark: Mark) -> Int? {
        switch base {
        case Ch.a: return mark == .breve ? 1 : (mark == .hat ? 2 : 0)
        case Ch.e: return mark == .hat ? 4 : 3
        case Ch.i: return 5
        case Ch.o: return mark == .hat ? 7 : (mark == .horn ? 8 : 6)
        case Ch.u: return mark == .horn ? 10 : 9
        case Ch.y: return 11
        default: return nil
        }
    }

    static func emitVowel(row: Int, tone: Tone, upper isUpper: Bool, charset: Charset,
                          into out: inout String.UnicodeScalarView) {
        switch charset {
        case .unicode:
            out.append((isUpper ? upper : lower)[row][tone.rawValue])
        case .unicodeCombining:
            out.append((isUpper ? upper : lower)[row][0])
            if tone != .none { out.append(Unicode.Scalar(combining[tone.rawValue])!) }
        case .tcvn3:
            let v = (isUpper && tone == .none) ? tcvn3UpperPlain[row] : tcvn3[row][tone.rawValue]
            out.append(Unicode.Scalar(v)!)
        }
    }

    static func emitD(upper isUpper: Bool, charset: Charset, into out: inout String.UnicodeScalarView) {
        if charset == .tcvn3 {
            out.append(Unicode.Scalar(isUpper ? UInt8(0xA7) : UInt8(0xAE)))
        } else {
            out.append(isUpper ? "Đ" : "đ")
        }
    }

    // MARK: - Quy tắc âm tiết

    static let initials: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng",
        "ngh", "nh", "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
    ]
    /// Phụ âm đầu đang gõ dở (chưa có nguyên âm).
    static let initialPrefixes: Set<String> = initials.union(["q"])

    /// Phụ âm đầu kiểu viết thân mật (miền Nam), luôn được chấp nhận: zậy, zui, dzô, qá.
    static let informalInitials: Set<String> = ["z", "dz", "q"]

    static let finals: Set<String> = ["c", "ch", "m", "n", "ng", "nh", "p", "t"]

    enum FinalRule { case open, closed, both }

    /// Nguyên âm (chưa có thanh) hợp lệ và việc có/không được phép có phụ âm cuối.
    static let clusters: [String: FinalRule] = [
        // "ă", "â" đứng một mình được (tên chữ cái), nên không bắt buộc phụ âm cuối.
        "a": .both, "ă": .both, "â": .both, "e": .both, "ê": .both, "i": .both,
        "o": .both, "ô": .both, "ơ": .both, "u": .both, "ư": .both, "y": .both,
        "ai": .open, "ao": .open, "au": .open, "ay": .open, "âu": .open, "ây": .open,
        "eo": .open, "êu": .open, "ia": .open, "iê": .closed, "iu": .open,
        "oa": .both, "oă": .closed, "oe": .both, "oi": .open, "oo": .closed,
        "ôi": .open, "ơi": .open, "ua": .open, "uâ": .closed, "uê": .both, "ui": .open,
        "uô": .closed, "uơ": .open, "uy": .both, "ưa": .open, "ưi": .open, "ươ": .both,
        "ưu": .open, "yê": .closed,
        "iêu": .open, "yêu": .open, "oai": .open, "oay": .open, "oeo": .open, "uây": .open,
        "uôi": .open, "ươi": .open, "ươu": .open, "uyê": .closed, "uya": .open, "uyu": .open,
    ]

    /// Dạng không mũ/móc (chỉ chữ cái gốc) — dùng khi đang gõ dở.
    static let baseCanClose: Set<String> = Set(clusters.filter { $0.value != .open }.keys.map(stripMarks))

    static let basePrefixes: Set<String> = {
        var s: Set<String> = []
        for k in clusters.keys {
            let b = stripMarks(k)
            for n in 1...b.count { s.insert(String(b.prefix(n))) }
        }
        return s
    }()

    static func stripMarks(_ s: String) -> String {
        String(s.map { c -> Character in
            switch c {
            case "ă", "â": return "a"
            case "ê": return "e"
            case "ô", "ơ": return "o"
            case "ư": return "u"
            default: return c
            }
        })
    }
}
