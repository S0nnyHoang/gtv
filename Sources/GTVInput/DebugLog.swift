import Foundation

/// Log chẩn đoán, chỉ có trong bản Debug: ~/Library/Logs/GTV-debug.log
enum DebugLog {
    static func write(_ message: @autoclosure () -> String) {
        #if DEBUG
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/GTV-debug.log")
        let line = "\(Date().timeIntervalSince1970) \(message())\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(line.data(using: .utf8)!)
            try? h.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
    }
}
