// ============================================================
// AppLogger — singleton in-app log buffer
// Drop-in replacement for print() that also feeds the Debug tab.
// Usage: AppLogger.shared.log("🔄 Reconnecting...")
//        AppLogger.log("❌ Decode error: \(err)")   // static convenience
// ============================================================

import Foundation
import Combine


struct LogEntry: Identifiable {
    let id   = UUID()
    let date = Date()
    let text: String

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: date)
    }
}

final class AppLogger: ObservableObject {
    static let shared = AppLogger()

    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries = 500
    private let queue = DispatchQueue(label: "AppLogger", qos: .utility)

    private init() {}

    /// Append a log line. Thread-safe, always posts to main for @Published.
    func log(_ text: String) {
        // Still mirror to Xcode console
        print(text)
        queue.async { [weak self] in
            guard let self else { return }
            let entry = LogEntry(text: text)
            DispatchQueue.main.async {
                self.entries.append(entry)
                if self.entries.count > self.maxEntries {
                    self.entries.removeFirst(self.entries.count - self.maxEntries)
                }
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { self.entries.removeAll() }
    }

    // Static convenience so callers don't need the `.shared` ceremony
    static func log(_ text: String) { shared.log(text) }
}
