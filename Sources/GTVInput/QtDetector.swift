import AppKit

/// Nhận biết ứng dụng viết bằng Qt (Telegram Desktop, OBS, VirtualBox…). Ứng dụng Qt cần cách thay chữ
/// riêng khi chuỗi thay vào trùng ký tự phím vừa bấm (xem `Session.replace`).
///
/// Dấu hiệu: có QtCore/QtGui.framework trong gói (Qt liên kết động), hoặc file chạy chứa tên lớp
/// "QNSView" (Qt liên kết tĩnh, như Telegram). Kiểm tra ở luồng nền một lần cho mỗi ứng dụng; trong lúc
/// chưa có kết quả thì coi là không phải Qt.
enum QtDetector {
    private static var cache: [String: Bool] = [:]
    private static var pending: Set<String> = []
    private static let queue = DispatchQueue(label: "gtv.qt-detector", qos: .utility)

    static func isQt(_ bundleID: String) -> Bool {
        if let known = cache[bundleID] { return known }
        guard !bundleID.isEmpty, !pending.contains(bundleID) else { return false }
        let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.bundleURL
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        guard let app else { return false }
        pending.insert(bundleID)
        queue.async {
            let result = detect(app)
            DispatchQueue.main.async {
                cache[bundleID] = result
                pending.remove(bundleID)
            }
        }
        return false
    }

    private static func detect(_ app: URL) -> Bool {
        guard let bundle = Bundle(url: app) else { return false }
        let fm = FileManager.default
        for name in ["QtCore.framework", "QtGui.framework"] {
            if fm.fileExists(atPath: bundle.bundlePath + "/Contents/Frameworks/" + name) { return true }
        }
        guard let exe = bundle.executableURL,
              let data = try? Data(contentsOf: exe, options: .alwaysMapped) else { return false }
        let needle = Array("QNSView".utf8)
        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            return needle.withUnsafeBytes { n in
                memmem(base, raw.count, n.baseAddress, n.count) != nil
            }
        }
    }
}
