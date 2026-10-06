# GTV – Gõ Tiếng Việt cho macOS

Bộ gõ tiếng Việt viết bằng Swift + InputMethodKit, nhắm vào 2 lỗi phổ biến:

| Lỗi | Nguyên nhân | Cách GTV xử lý |
|---|---|---|
| Gạch chân chữ đang gõ (bộ gõ có sẵn của macOS) | Dùng *marked text* (vùng soạn thảo tạm) | Không dùng marked text: chữ được ghi thẳng vào ô nhập liệu |
| "dđ", "oô", "uư" ở thanh địa chỉ / ô tìm kiếm (bộ gõ bên thứ 3) | Gửi phím Backspace giả để xoá chữ cũ. Khi trình duyệt đang bôi đen phần **gợi ý tự động**, Backspace chỉ xoá phần gợi ý chứ không xoá chữ cũ | Không gửi phím giả. Thay đúng đoạn chữ trước con trỏ bằng `insertText(_:replacementRange:)`; vùng gợi ý đang bôi đen cũng nằm trong vùng thay thế |

Trước mỗi lần thay, GTV đọc lại văn bản trước con trỏ để kiểm tra có khớp với từ đang gõ không.
Nếu không khớp (ví dụ đã click sang chỗ khác) thì bắt đầu một từ mới, không bao giờ ghi sai chỗ.

Tài liệu kỹ thuật chi tiết (kiến trúc, lý do thiết kế, giải thích code): [docs/TECHNICAL.md](docs/TECHNICAL.md).

## Tính năng

- Kiểu gõ: **Telex**, **VNI**, **Telex đơn giản** (`w` đứng riêng không thành `ư`, không dùng `[ ]`)
- Bảng mã: **Unicode dựng sẵn**, **Unicode tổ hợp**, **TCVN3 (ABC)**
- Đặt dấu kiểu cũ (`hòa`, `thúy`, mặc định) hoặc kiểu mới (`hoà`, `thuý`); bỏ dấu tự do (`nguoiwf` → `người`)
- Gõ phím lặp lại để huỷ (`ass` → `as`, `ddd` → `dd`, `ww` → `w`)
- Tự khôi phục từ không phải tiếng Việt: gõ `windows`, `facebook`, `text`… ra đúng chữ mà không cần tắt bộ gõ
- Kiểu viết thân mật: phụ âm đầu `z`, `dz`, `q` không có `u` — `zij` → `zị`, `zaayj` → `zậy`, `dzoo` → `dzô`, `qas` → `qá`. Đánh đổi: vài từ tiếng Anh trùng với cách gõ một âm tiết thân mật sẽ không được tự khôi phục (`zoom` → `zôm`, `zero` → `zẻo`)
- Ứng dụng không gõ tiếng Việt (vd. IDE): khi chuyển sang, GTV tự đổi sang chế độ tiếng Anh; khi rời đi thì quay lại tiếng Việt nếu trước đó đang gõ tiếng Việt. Thêm/bỏ trong menu V/E: *Không gõ tiếng Việt trong …* (ứng dụng đang dùng) hoặc *Ứng dụng không gõ tiếng Việt → Thêm ứng dụng…*. Trong các ứng dụng này không gõ được tiếng Việt: nếu chọn lại tiếng Việt (⌘⇧, menu bộ gõ, phím 🌐) thì GTV tự chuyển về tiếng Anh
- Chế độ gạch chân cho các ứng dụng không hỗ trợ thay thế văn bản (mặc định bật cho Terminal, iTerm2, kitty, Alacritty, WezTerm, Warp, Ghostty); bật/tắt cho từng ứng dụng trong menu

## Chạy như một app riêng

- Mở GTV từ Applications/Spotlight: app tự cài bộ gõ vào `~/Library/Input Methods` và tự chọn nó. Không cần vào Cài đặt bàn phím. macOS chỉ hỏi cho phép thêm bộ gõ ở lần cài đầu tiên.
- GTV có 2 chế độ: **Tiếng Việt (GTV)** và **Tiếng Anh (GTV)**. Biểu tượng bộ gõ của macOS hiện **V** / **E** theo chế độ.
- Chuyển Anh/Việt: nhấn rồi nhả **⌘⇧ (Command + Shift)** (đổi được trong menu: ⌘⇧, ⌃⇧, ⌥⇧ hoặc không dùng), chọn trong menu bộ gõ, hoặc phím 🌐 / Ctrl+Space. Có âm báo của hệ thống khi chuyển (tắt được trong menu).
- Mọi cài đặt nằm trong **menu bộ gõ của macOS**. Muốn có biểu tượng V/E riêng như Unikey thì bật *Hiện biểu tượng GTV trên thanh menu*.
- **Chọn GTV khi đăng nhập** (mặc định bật, tắt được trong menu): GTV.app nằm trong *Mở khi đăng nhập*; khi đăng nhập nếu đang ở bộ gõ khác (vd. ABC) thì tự chọn Tiếng Việt (GTV), nếu đang ở GTV thì giữ nguyên chế độ.
- Nhiều bộ gõ (vd. GTV + tiếng Nhật): đổi giữa các bộ gõ bằng phím 🌐 / ⌃Space của macOS; ⌘⇧ chỉ chuyển Việt ↔ Anh khi đang ở GTV. Không cần bỏ ABC: nó chỉ nằm trong vòng xoay của 🌐 / ⌃Space; lúc đăng nhập GTV tự được chọn, và khi thoát GTV hệ thống quay về ABC.
- **Thoát GTV** trong menu: chuyển về bàn phím ABC rồi tắt hẳn. Mở lại GTV để dùng tiếp (không bị hỏi lại).

Bên trong, phần gõ là một input source của macOS (`GTVInput.app`), vì chỉ input source mới thay được
chữ trong ô nhập liệu mà không phải gửi phím Backspace giả.

Vì sao tiếng Anh là một chế độ của GTV chứ không chuyển sang bàn phím ABC: khi một input method được
chọn bằng lệnh từ nền, ứng dụng đang dùng thường gắn bộ gõ rồi gỡ ra ngay (gõ không ra tiếng Việt cho
tới khi đổi ứng dụng). Cách vá duy nhất là làm ứng dụng mất focus rồi lấy lại, gây nháy cửa sổ. Chuyển
giữa 2 chế độ của cùng một bộ gõ thì không có vấn đề này: không nháy, ⌘⇧ luôn do bộ gõ bắt được, không
cần theo dõi phím nền.

Khi cập nhật, GTV chỉ chép đè các file bên trong bộ gõ chứ không xoá thư mục của nó (xoá thư mục sẽ
khiến macOS gỡ bộ gõ khỏi danh sách và hỏi lại người dùng).

## Hiệu năng

- Chỉ một tiến trình chạy ngầm: bộ nhớ thực dùng ~12 MB, không tốn CPU khi rảnh (không timer, không
  event tap, không theo dõi phím nền, không cần quyền Trợ năng)
- Phím thường không cần thêm dấu được trả lại cho ứng dụng xử lý như bình thường; GTV chỉ can thiệp khi thật sự cần đổi chữ
- Ở chế độ E, phím đi thẳng qua mà không xử lý gì thêm

## Build & phát hành

Cần Xcode trên macOS 12 trở lên.

- **Xcode:** mở `GTV.xcodeproj`, chọn scheme **GTV**, bấm Run (⌘R) hoặc Test (⌘U).
  Project được sinh từ `project.yml` bằng [XcodeGen](https://github.com/yonaskolb/XcodeGen):
  thêm/xoá file hay đổi cài đặt build thì sửa `project.yml` rồi chạy `xcodegen`.
  (`GTV.xcodeproj` vẫn mở bình thường khi không có XcodeGen.)
- **Dòng lệnh:**

```bash
./build.sh       # build/GTV.app (Release, universal arm64 + x86_64)
./dmg.sh         # build/GTV-<phiên bản>.dmg để gửi cho người dùng
./install.sh     # (lúc phát triển) build, chép vào /Applications và mở
./uninstall.sh   # gỡ
xcrun swift test # chạy nhanh test của bộ xử lý gõ
```

Người dùng chỉ cần mở file `.dmg`, kéo **GTV** vào **Applications**, rồi mở GTV.

### Ký & notarize

Đang đi mua acc dev :(

## Cấu trúc

```
project.yml           Cấu hình Xcode project (XcodeGen) -> GTV.xcodeproj
Sources/VietEngine/   Bộ xử lý gõ thuần Swift (không phụ thuộc AppKit)
  Engine.swift        Phân tích âm tiết, biến đổi Telex/VNI, đặt dấu, khôi phục
  Tables.swift        Bảng mã Unicode/TCVN3, quy tắc âm tiết hợp lệ
  Session.swift       Nối engine với ô nhập liệu: thay văn bản, phát hiện văn bản bị đổi
                      ngoài tầm bộ gõ (Cmd+A, Cmd+Z, chuột...) và đọc lại từ trên màn hình
Sources/GTVInput/     Bộ gõ (InputMethodKit) + biểu tượng V/E, chạy chung một tiến trình
  InputController.swift  Nhận phím, phím tắt chuyển Anh/Việt, chuyển cho Session
  StatusController.swift Theo dõi Anh/Việt; biểu tượng V/E (tuỳ chọn) trên thanh menu
  AppMenu.swift       Menu cài đặt (menu bộ gõ macOS và biểu tượng V/E)
  Modes.swift         Chế độ Tiếng Việt/Tiếng Anh, ứng dụng loại trừ
  InputSources.swift  Đọc/chọn bộ gõ của macOS
  Hotkey.swift        Nhận biết nhấn-nhả phím tắt "trơn" (không kèm phím/click khác)
  Settings.swift      Cài đặt (UserDefaults)
Sources/GTVLauncher/  GTV.app: cài/cập nhật bộ gõ, chọn nó, khởi động rồi thoát
Resources/            Info.plist, icon (vẽ lại bằng scripts/make_icon*.swift)
Tests/                Test engine + Session (ô nhập liệu giả có gợi ý tự động, Cmd+A...)
```
