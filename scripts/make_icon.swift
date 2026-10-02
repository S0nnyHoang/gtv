// Vẽ icon bộ gõ (template) cho thanh menu: swift make_icon.swift <out.tiff> <chữ> [png-xem-trước]
// Theo đúng kích thước icon ABC trên thanh menu: khung 22×16 pt, nền đặc kín khung bo góc,
// chữ khoét rỗng ở giữa (đo từ ảnh chụp màn hình). Bản @1x và @2x.
import AppKit

let args = CommandLine.arguments
let out = args[1]
let letter = args.count > 2 ? args[2] : "V"
let preview = args.count > 3 ? args[3] : nil

let W: CGFloat = 22, H: CGFloat = 16

func draw(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W) * scale, pixelsHigh: Int(H) * scale, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(x: 0, y: 0, width: W, height: H)
    NSColor.black.set()
    NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

    // Chữ cao bằng chữ "A" của icon ABC (~8,5 pt), căn giữa theo khung bao thật của nét chữ.
    let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    let text = NSAttributedString(string: letter, attributes: [.font: font, .foregroundColor: NSColor.black])
    let ctx = NSGraphicsContext.current!.cgContext
    let line = CTLineCreateWithAttributedString(text)
    let glyph = CTLineGetImageBounds(line, ctx)
    ctx.setBlendMode(.destinationOut)
    ctx.textPosition = CGPoint(x: (W - glyph.width) / 2 - glyph.minX, y: (H - glyph.height) / 2 - glyph.minY)
    CTLineDraw(line, ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let image = NSImage(size: NSSize(width: W, height: H))
image.addRepresentation(draw(scale: 1))
image.addRepresentation(draw(scale: 2))
try! image.tiffRepresentation(using: .lzw, factor: 0)!.write(to: URL(fileURLWithPath: out))

if let preview {
    let big = draw(scale: 8)
    // Giống menu tối trong ảnh chụp: nền tối, icon màu sáng.
    let canvas = NSImage(size: NSSize(width: 240, height: 160))
    canvas.lockFocus()
    NSColor(white: 0.13, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 240, height: 160).fill()
    let icon = NSImage(cgImage: big.cgImage!, size: NSSize(width: W * 5, height: H * 5))
    let tinted = NSImage(size: icon.size)
    tinted.lockFocus()
    NSColor(white: 0.9, alpha: 1).set()
    NSRect(origin: .zero, size: icon.size).fill()
    icon.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1)
    tinted.unlockFocus()
    tinted.draw(in: NSRect(x: (240 - W * 5) / 2, y: (160 - H * 5) / 2, width: W * 5, height: H * 5))
    canvas.unlockFocus()
    let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: preview))
}
