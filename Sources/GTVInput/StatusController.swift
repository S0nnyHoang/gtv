import AppKit
import Carbon

/// Biểu tượng V/E trên thanh menu (tuỳ chọn, mặc định ẩn).
final class StatusController: NSObject, NSMenuDelegate {
    static let shared = StatusController()

    private var item: NSStatusItem?
    private lazy var iconV = StatusController.icon("V")
    private lazy var iconE = StatusController.icon("E")

    func start() {
        refresh()

        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: .gtvSettingsChanged, object: nil)
        // Người dùng đổi bộ gõ bằng menu của macOS / phím Globe.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(refresh),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil)
        #if DEBUG
        // Cho phép test bật/tắt từ bên ngoài như khi bấm menu.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.gtv.debug.toggle"), object: nil, queue: .main) { _ in
            Modes.shared.toggle()
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.gtv.debug.menutoggle"), object: nil, queue: .main) { [weak self] n in
            guard let self else { return }
            // Giống menu bộ gõ của macOS: mục menu bị chép sang tiến trình khác, chỉ còn tag.
            let tag = Int(n.object as? String ?? "") ?? 1
            let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            let menu = AppMenu.build(target: self, action: #selector(self.menuAction(_:)), appBundleID: app, standalone: false)
            func find(_ m: NSMenu) -> NSMenuItem? {
                for it in m.items {
                    if it.tag == tag && it.action != nil { return it }
                    if let sub = it.submenu, let r = find(sub) { return r }
                }
                return nil
            }
            guard let found = find(menu) else { return }
            let copy = NSMenuItem(title: found.title, action: nil, keyEquivalent: "")
            copy.tag = found.tag
            AppMenu.perform(copy, appBundleID: app)
            self.refresh()
        }
        #endif
    }

    @objc private func refresh() {
        let on = Modes.shared.vietnamese && InputSources.isGTVSelected

        if Settings.shared.showStatusIcon {
            if item == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                let menu = NSMenu()
                menu.delegate = self
                item.menu = menu
                self.item = item
            }
            item?.button?.image = on ? iconV : iconE
            item?.button?.toolTip = on ? "GTV: Tiếng Việt" : "GTV: Tiếng Anh"
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    // Dựng lại menu mỗi lần mở để trạng thái luôn đúng (và không tốn gì khi không mở).
    func menuNeedsUpdate(_ menu: NSMenu) {
        let appID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let fresh = AppMenu.build(target: self, action: #selector(menuAction(_:)), appBundleID: appID, standalone: true)
        menu.removeAllItems()
        for i in fresh.items {
            fresh.removeItem(i)
            menu.addItem(i)
        }
    }

    @objc fileprivate func menuAction(_ sender: NSMenuItem) {
        AppMenu.perform(sender, appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "")
        refresh()
    }

    /// Cùng kiểu icon bộ gõ (scripts/make_icon.swift): khung 22×16 như icon ABC, nền đặc, chữ khoét rỗng.
    private static func icon(_ letter: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { rect in
            NSColor.black.set()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            let text = NSAttributedString(string: letter, attributes: [.font: font, .foregroundColor: NSColor.black])
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            let line = CTLineCreateWithAttributedString(text)
            let glyph = CTLineGetImageBounds(line, ctx)   // căn giữa theo nét chữ thật
            ctx.setBlendMode(.destinationOut)
            ctx.textPosition = CGPoint(x: (rect.width - glyph.width) / 2 - glyph.minX,
                                       y: (rect.height - glyph.height) / 2 - glyph.minY)
            CTLineDraw(line, ctx)
            return true
        }
        image.isTemplate = true
        return image
    }
}
