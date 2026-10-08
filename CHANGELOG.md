# Nhật ký thay đổi

Mỗi phiên bản là một mục `## <phiên bản> — <ngày>`. Nội dung của mục được dùng nguyên văn làm release
note trên trang GitHub Releases (workflow `Release`). Phiên bản phải khớp `MARKETING_VERSION` trong
`project.yml`.

## 1.10.5 — 2026-10-06

### Sửa lỗi
- Telex: gõ `ww`, `[[`, `]]` trong ô nhập liệu của trang web (Chrome, ô "Ask Google"…) và các ứng dụng
  Electron như Claude desktop ra `ưw`, `ơ[`, `ư]` thay vì `w`, `[`, `]`.

## 1.10.4 — 2026-10-05

### Sửa lỗi
- Telegram Desktop: gõ `[[`, `]]`, `ww` ra `ơ[`, `ư]`, `ưw`.

## 1.10.3 — 2026-10-05

### Thay đổi
- Telex: gõ `[` hai lần ra dấu `[` (thay vì `ơơ`), tương tự `]` → `]`, `{` → `{`, `}` → `}`.

## 1.10.2 — 2026-10-03

### Sửa lỗi
- Sau khi gập máy (hoặc máy ngủ) rồi mở lại, bộ gõ ở lại ABC thay vì quay về GTV.

## 1.10.1 — 2026-10-03

### Thay đổi
- Kiểu viết thân mật luôn bật, bỏ tuỳ chọn trong menu.

## 1.10 — 2026-10-03

### Tính năng mới
- Hỗ trợ kiểu viết thân mật: `zậy`, `zị`, `dzô`, `qá` (phụ âm đầu `z`, `dz`, `q` không cần `u`).

## 1.9.3 — 2026-10-02

### Sửa lỗi
- Khoá màn hình rồi mở khoá, bộ gõ ở lại ABC thay vì quay về GTV.

## 1.9.2 — 2026-10-02

### Tính năng mới
- Hiện phiên bản trong menu GTV.

## 1.9 — 2026-10-02

### Thay đổi
- Icon bộ gõ cùng kích thước với icon ABC; icon ứng dụng trong danh sách loại trừ.
- Lần cài đầu: nếu không bật được bộ gõ, hiện hướng dẫn thêm bằng tay.

## 1.8 — 2026-10-02

### Tính năng mới
- Tự chọn GTV khi đăng nhập (tắt được trong menu).

## 1.7 — 2026-10-02

### Thay đổi
- Tiếng Anh là một chế độ của GTV ("English (GTV)"): chuyển Anh/Việt không còn nháy cửa sổ.
- Âm báo của hệ thống khi chuyển Anh/Việt (tắt được trong menu).

## 1.6 — 2026-10-02

### Thay đổi
- Phím chuyển Anh/Việt mặc định là ⌘⇧ (Command + Shift); thêm lựa chọn ⌥⇧.
- Mặc định đặt dấu kiểu cũ (`hòa`, `thúy`).
- Danh sách ứng dụng loại trừ hiện dạng menu con.

## 1.5 — 2026-10-02

### Thay đổi
- Mọi cài đặt nằm trong menu bộ gõ của macOS; biểu tượng V/E riêng thành tuỳ chọn.
- Ứng dụng loại trừ không bao giờ gõ tiếng Việt.

## 1.4 — 2026-10-02

### Tính năng mới
- Ứng dụng không gõ tiếng Việt (vd. IDE): tự chuyển sang tiếng Anh khi dùng ứng dụng đó.

## 1.0 – 1.3 — 2026-10-02

### Tính năng mới
- Bộ gõ tiếng Việt cho macOS: Telex, VNI, Telex đơn giản; Unicode dựng sẵn, Unicode tổ hợp, TCVN3.
- Không gạch chân chữ đang gõ; không lỗi "dđ" ở thanh địa chỉ trình duyệt.
- Tự khôi phục từ tiếng Anh, bỏ dấu tự do, gõ lặp để huỷ dấu.
- App riêng: mở GTV là tự cài và chọn bộ gõ; phím tắt chuyển Anh/Việt.
