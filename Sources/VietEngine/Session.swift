/// Ô nhập liệu mà bộ gõ làm việc cùng (InputMethodKit client, hoặc bản giả trong test).
/// Mọi vị trí tính theo UTF-16.
public protocol TextClient: AnyObject {
    /// nil nếu ứng dụng không cho biết vị trí con trỏ.
    func selectedRange() -> (location: Int, length: Int)?
    /// nil nếu ứng dụng không cho đọc văn bản.
    func text(location: Int, length: Int) -> String?
    func replaceText(location: Int, length: Int, with text: String)
    func setMarkedText(_ text: String)
    func insertText(_ text: String)
    /// Thay một đoạn bằng `text` qua marked text rồi chốt ngay (dùng cho ứng dụng Qt, xem `replace`).
    func replaceViaMarkedText(location: Int, length: Int, with text: String)
}

public enum Key: Equatable {
    case char(Character)
    case backspace
    /// Enter, Tab, mũi tên, tổ hợp Cmd/Ctrl/Option...: kết thúc từ.
    case other
}

/// Nối Engine với một ô nhập liệu: quyết định cho phím đi qua, thay văn bản hay dùng marked text,
/// và phát hiện khi văn bản bị thay đổi bởi thao tác mà bộ gõ không thấy (Cmd+A, Cmd+Z, chuột...).
public final class Session {
    public let engine = Engine()
    private var marked = false   // từ hiện tại dùng marked text (gạch chân)
    private var anchor = 0       // vị trí bắt đầu của từ đang gõ
    private var qtApp = false    // ô nhập liệu thuộc ứng dụng Qt (xem `replace`)

    public init() {}

    public func reset() {
        engine.reset()
        marked = false
    }

    /// Trả về true nếu bộ gõ đã xử lý phím (ứng dụng không cần xử lý nữa).
    /// `qtApp`: ứng dụng viết bằng Qt (Telegram Desktop…), cần cách thay riêng — xem `replace`.
    public func handle(_ key: Key, _ client: TextClient, options: EngineOptions, forceMarked: Bool,
                       qtApp: Bool = false) -> Bool {
        self.qtApp = qtApp
        switch key {
        case .other:
            breakWord(client)
            return false
        case .backspace:
            return backspace(client)
        case let .char(ch):
            if engine.isEmpty {
                engine.options = options
                let sel = client.selectedRange()
                marked = forceMarked || sel == nil
                anchor = sel?.location ?? 0
            } else if !marked && !inSync(client.selectedRange()) {
                resync(client)
            }
            guard let action = engine.process(ch) else {
                breakWord(client)
                return false
            }
            if marked {
                client.setMarkedText(engine.displayed)
                return true
            }
            return perform(action, client, retry: ch)
        }
    }

    /// Chốt từ đang gõ (khi ô nhập liệu mất focus, click chuột...).
    public func commit(_ client: TextClient?) {
        if marked, !engine.isEmpty, let client {
            client.insertText(engine.finishWord().text)
        }
        reset()
    }

    // MARK: -

    /// Con trỏ có đang nằm ngay sau từ đang gõ không.
    private func inSync(_ sel: (location: Int, length: Int)?) -> Bool {
        guard let sel else { return false }
        return sel.location == anchor + engine.displayed.utf16.count
    }

    private func backspace(_ client: TextClient) -> Bool {
        guard !engine.isEmpty else { return false }
        if marked {
            _ = engine.backspace()
            client.setMarkedText(engine.displayed)
            if engine.isEmpty { marked = false }
            return true
        }
        let sel = client.selectedRange()
        guard let sel, inSync(sel) else {
            engine.reset()          // văn bản đã đổi ngoài tầm bộ gõ (vd. Cmd+A): bỏ từ đang gõ
            return false
        }
        if sel.length > 0 { return false }   // chỉ xoá phần gợi ý tự động đang bôi đen sau từ
        return perform(engine.backspace(), client, retry: nil)
    }

    private func breakWord(_ client: TextClient) {
        guard !engine.isEmpty else { return }
        let (text, action) = engine.finishWord()
        if marked {
            client.insertText(text)
        } else if case let .replace(old, new) = action {
            _ = replace(old, new, client)
        }
        marked = false
    }

    private func perform(_ action: Action, _ client: TextClient, retry ch: Character?) -> Bool {
        guard case let .replace(old, new) = action else { return false }
        if replace(old, new, client, typed: ch) { return true }
        // Không khớp với màn hình: đọc lại từ trước con trỏ rồi xử lý phím này tiếp từ đó.
        resync(client)
        guard let ch else { engine.reset(); return false }
        if let a = engine.process(ch), case let .replace(o, n) = a {
            if replace(o, n, client, typed: ch) { return true }
            engine.reset()
        }
        return false
    }

    /// Bỏ trạng thái hiện tại, nạp lại từ đang nằm ngay trước con trỏ (nếu đọc được).
    private func resync(_ client: TextClient) {
        engine.reset()
        guard let sel = client.selectedRange() else { return }
        anchor = sel.location
        guard sel.location > 0 else { return }
        let len = min(sel.location, 16)
        guard let text = client.text(location: sel.location - len, length: len) else { return }
        let word = String(text.reversed().prefix(while: { $0.isLetter }).reversed())
        // Chỉ nạp khi thấy trọn từ (đứng sau ký tự không phải chữ, hoặc ở đầu văn bản).
        guard !word.isEmpty, word.utf16.count < len || len == sel.location else { return }
        if engine.seed(word) { anchor = sel.location - word.utf16.count }
    }

    /// `typed`: ký tự của phím vừa bấm (nếu việc thay đổi do phím đó gây ra).
    private func replace(_ old: String, _ new: String, _ client: TextClient, typed: Character? = nil) -> Bool {
        let oldLen = old.utf16.count
        guard let sel = client.selectedRange(), sel.location >= oldLen,
              sel.location == anchor + oldLen else { return false }
        if oldLen > 0, let current = client.text(location: sel.location - oldLen, length: oldLen), current != old {
            return false
        }
        // Chỉ thay phần khác nhau để ứng dụng phải làm ít việc nhất.
        var common = 0
        var oi = old.startIndex, ni = new.startIndex
        while oi < old.endIndex, ni < new.endIndex, old[oi] == new[ni] {
            common += old[oi].utf16.count
            oi = old.index(after: oi)
            ni = new.index(after: ni)
        }
        let deleteLen = oldLen - common
        let insert = String(new[ni...])
        let start = sel.location - deleteLen
        // Vùng đang bôi đen sau từ (gợi ý tự động) cũng bị thay luôn.
        let length = deleteLen + sel.length
        if qtApp, let typed, insert == String(typed), length > 0 {
            // Chuỗi thay vào trùng ký tự phím vừa bấm (vd. "ơ" + "[" -> "[", "ư" + "w" -> "w"): ứng dụng Qt
            // (Telegram...) coi đó là nhấn phím thường, bỏ qua vùng cần thay (và bỏ qua cả lệnh thay bằng
            // chuỗi rỗng) -> "ơ[". Đi qua marked text thì Qt xử lý theo đường của bộ gõ.
            // Chỉ dùng cho Qt: ô nhập liệu trong trang web (Chrome, Electron) lại bỏ qua vùng cần thay
            // của marked text, còn cách thay trực tiếp thì đúng.
            client.replaceViaMarkedText(location: start, length: length, with: insert)
        } else {
            client.replaceText(location: start, length: length, with: insert)
        }
        return true
    }
}
