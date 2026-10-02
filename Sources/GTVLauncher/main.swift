// GTV.app (trong /Applications): cài hoặc cập nhật bộ gõ ẩn vào ~/Library/Input Methods,
// chọn nó làm bộ gõ hiện tại, khởi động nó (biểu tượng V/E hiện trên thanh menu) rồi thoát.
//
// Lưu ý: không bao giờ xoá thư mục bộ gõ đã cài. Khi thư mục biến mất, macOS gỡ GTV khỏi danh sách
// bộ gõ và lần bật lại sẽ phải hỏi người dùng. Vì vậy chỉ cập nhật các file bên trong, và chỉ bật
// bộ gõ khi nó chưa được bật.
import Carbon
import Cocoa
import ServiceManagement

let inputID = "com.gtv.inputmethod.GTV"
let fm = FileManager.default
let bundled = Bundle.main.resourceURL!.appendingPathComponent("GTVInput.app")
let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods")
let installed = dir.appendingPathComponent("GTVInput.app")
let legacy = dir.appendingPathComponent("GTV.app")   // bản cài trước đây (chỉ có bộ gõ)

/// Đồng bộ mục "Mở khi đăng nhập" của GTV.app với cài đặt "Chọn GTV khi đăng nhập" (lưu trong
/// cài đặt của bộ gõ, mặc định bật). Khi đăng nhập, GTV.app chạy và chọn GTV nếu đang ở bộ gõ khác.
func syncLoginItem() {
    guard #available(macOS 13.0, *) else { return }
    let want = UserDefaults(suiteName: inputID)?.object(forKey: "selectAtLogin") as? Bool ?? true
    let service = SMAppService.mainApp
    do {
        if want && service.status != .enabled {
            try service.register()
        } else if !want && service.status == .enabled {
            try service.unregister()
        }
    } catch {
        print("Không cập nhật được mục Mở khi đăng nhập: \(error.localizedDescription)")
    }
}

// `GTV --sync-login-item`: bộ gõ gọi khi người dùng bật/tắt "Chọn GTV khi đăng nhập".
if CommandLine.arguments.contains("--sync-login-item") {
    syncLoginItem()
    exit(0)
}

func fail(_ message: String) -> Never {
    NSApplication.shared.setActivationPolicy(.accessory)
    let alert = NSAlert()
    alert.messageText = "Không khởi động được GTV"
    alert.informativeText = message
    alert.runModal()
    exit(1)
}

/// Hai bản có giống hệt nhau không (so sánh file thực thi và Info.plist).
func sameBuild(_ a: URL, _ b: URL) -> Bool {
    for path in ["Contents/MacOS/GTVInput", "Contents/Info.plist"] {
        guard let x = fm.contents(atPath: a.appendingPathComponent(path).path),
              let y = fm.contents(atPath: b.appendingPathComponent(path).path), x == y else { return false }
    }
    return true
}

func stopRunningInput() {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: inputID)
    apps.forEach { $0.forceTerminate() }
    let deadline = Date().addingTimeInterval(3)
    while apps.contains(where: { !$0.isTerminated }) && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
}

/// Chép đè nội dung bộ gõ nhưng giữ nguyên thư mục GTVInput.app.
func updateInPlace() throws {
    let rsync = Process()
    rsync.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
    rsync.arguments = ["-a", "--delete", bundled.path + "/", installed.path + "/"]
    try rsync.run()
    rsync.waitUntilExit()
    guard rsync.terminationStatus == 0 else {
        throw NSError(domain: "GTV", code: Int(rsync.terminationStatus),
                      userInfo: [NSLocalizedDescriptionKey: "rsync lỗi \(rsync.terminationStatus)"])
    }
}

/// Người dùng đã cho phép mở GTV.app; bản bộ gõ chép ra không cần bị Gatekeeper hỏi lại.
func clearQuarantine(_ url: URL) {
    let subpaths = (try? fm.subpathsOfDirectory(atPath: url.path)) ?? []
    for p in [url.path] + subpaths.map({ url.appendingPathComponent($0).path }) {
        removexattr(p, "com.apple.quarantine", XATTR_NOFOLLOW)
    }
}

func inputSources() -> [TISInputSource] {
    let filter = [kTISPropertyBundleID as String: inputID] as CFDictionary
    return TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
}

func property(_ src: TISInputSource, _ key: CFString) -> AnyObject? {
    guard let p = TISGetInputSourceProperty(src, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue()
}

func flag(_ src: TISInputSource, _ key: CFString) -> Bool {
    (property(src, key) as? NSNumber)?.boolValue ?? false
}

// 1. Cài / cập nhật
var updated = false
do {
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    if fm.fileExists(atPath: legacy.path) {
        stopRunningInput()
        try fm.removeItem(at: legacy)
    }
    if !fm.fileExists(atPath: installed.path) {
        try fm.copyItem(at: bundled, to: installed)
        updated = true
    } else if !sameBuild(bundled, installed) {
        stopRunningInput()
        try updateInPlace()
        updated = true
    }
    if updated { clearQuarantine(installed) }
} catch {
    fail("Không cài được bộ gõ vào \(dir.path): \(error.localizedDescription)")
}

// 2. Đăng ký (lần đầu hoặc sau khi cập nhật, để macOS đọc lại Info.plist)
var sources = inputSources()
if updated || sources.isEmpty {
    let status = TISRegisterInputSource(installed as CFURL)
    guard status == noErr else { fail("Đăng ký bộ gõ thất bại (mã lỗi \(status)).") }
    for _ in 0..<40 {
        sources = inputSources()
        if sources.contains(where: { property($0, kTISPropertyInputSourceID) as? String == inputID + ".vi" }) { break }
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
}
guard !sources.isEmpty else {
    fail("Đã cài bộ gõ nhưng macOS chưa nhận. Hãy đăng xuất rồi đăng nhập lại, sau đó mở GTV lần nữa.")
}

// 3. Bật (chỉ khi chưa bật — macOS sẽ hỏi người dùng ở lần đầu) rồi chọn GTV.
func vietnameseEnabled() -> Bool {
    inputSources().contains {
        property($0, kTISPropertyInputSourceID) as? String == inputID + ".vi" && flag($0, kTISPropertyInputSourceIsEnabled)
    }
}
var requestedEnable = false
for src in sources where !flag(src, kTISPropertyInputSourceIsEnabled) && flag(src, kTISPropertyInputSourceIsEnableCapable) {
    TISEnableInputSource(src)
    requestedEnable = true
}
if requestedEnable && !vietnameseEnabled() {
    // macOS có thể đang hiện hộp thoại xin phép: đợi người dùng trả lời (tối đa 1 phút).
    let deadline = Date().addingTimeInterval(60)
    while !vietnameseEnabled() && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    if !vietnameseEnabled() { showManualSetup() }
}

/// Đường lui khi macOS không cho bật bộ gõ bằng lệnh: hướng dẫn người dùng thêm bằng tay.
func showManualSetup() {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Thêm bộ gõ GTV"
    alert.informativeText = """
        macOS chưa bật bộ gõ GTV. Hãy thêm bằng tay:
        Cài đặt hệ thống → Bàn phím → Nguồn đầu vào → Sửa… → + → Tiếng Việt → \
        chọn "Vietnamese (GTV)" và "English (GTV)" → Thêm.

        Nếu không thấy GTV trong danh sách, hãy đăng xuất rồi đăng nhập lại và mở GTV lần nữa.
        """
    alert.addButton(withTitle: "Mở Cài đặt Bàn phím")
    alert.addButton(withTitle: "Để sau")
    if alert.runModal() == .alertFirstButtonReturn,
       let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
        NSWorkspace.shared.open(url)
    }
}
// Chọn chế độ Tiếng Việt (bộ gõ có 2 chế độ: <id>.vi và <id>.en) — trừ khi đang ở GTV rồi
// (vd. lần trước đăng xuất khi đang ở English (GTV) thì giữ nguyên).
@Sendable func isGTVSelected() -> Bool {
    guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
    return property(current, kTISPropertyBundleID) as? String == inputID
}
@Sendable func selectVietnamese() {
    let vietnameseMode = inputSources().first { property($0, kTISPropertyInputSourceID) as? String == inputID + ".vi" }
    if let target = vietnameseMode ?? inputSources().first(where: { flag($0, kTISPropertyInputSourceIsSelectCapable) }) {
        TISSelectInputSource(target)
    }
}
if !isGTVSelected() { selectVietnamese() }
syncLoginItem()

// Sau khi cập nhật: khởi động lại menu bộ gõ của macOS (hệ thống tự mở lại ngay) để nó đọc lại
// tên và icon mới của GTV, không phải đợi đăng nhập lại.
if updated {
    NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextInputMenuAgent")
        .forEach { $0.terminate() }
}

// 4. Khởi động ngay để biểu tượng V/E hiện lên (nếu đang chạy thì không mở thêm).
let config = NSWorkspace.OpenConfiguration()
config.activates = false
NSWorkspace.shared.openApplication(at: installed, configuration: config) { _, error in
    if let error { print("Không mở được bộ gõ: \(error.localizedDescription)") }
    DispatchQueue.main.async { ensureSelected(attempts: 10) }
}

/// Sau khi bộ gõ cũ bị tắt để cập nhật, macOS có thể tự chuyển sang ABC chậm hơn lệnh chọn ở trên.
func ensureSelected(attempts: Int) {
    let ok = isGTVSelected()
    if ok && attempts < 8 { exit(0) }   // đã đứng yên ở GTV một lúc
    if !ok { selectVietnamese() }
    if attempts == 0 { exit(0) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { ensureSelected(attempts: attempts - 1) }
}

RunLoop.main.run(until: Date().addingTimeInterval(10))
exit(0)
