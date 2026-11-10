// Draws the Mustop app icon (vinyl record + pause, teal→blue) as a 1024×1024 PNG.
// Usage: swift Scripts/make-icon.swift <out.png>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/Mustop-1024.png"
let side: CGFloat = 1024

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

let top: UInt32 = 0x5EE7DF, bottom: UInt32 = 0x4A6CF7, discShadow: UInt32 = 0x0B1A5C, accent: UInt32 = 0x4A6CF7

// macOS icon grid: 824pt body, 100pt margin, ~185 corner radius
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let sh = NSShadow(); sh.shadowColor = rgb(0x000000, 0.28); sh.shadowBlurRadius = 28; sh.shadowOffset = NSSize(width: 0, height: -12)
sh.set(); rgb(0x000000).setFill(); squircle.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(starting: rgb(top), ending: rgb(bottom))!.draw(in: squircle, angle: -90)

NSGraphicsContext.saveGraphicsState(); squircle.addClip()
let center = NSPoint(x: 512, y: 512)
let disc = NSRect(x: 197, y: 197, width: 630, height: 630)
NSGraphicsContext.saveGraphicsState()
let ds = NSShadow(); ds.shadowColor = rgb(discShadow, 0.5); ds.shadowBlurRadius = 30; ds.shadowOffset = NSSize(width: 0, height: -14); ds.set()
rgb(0x1C1C22).setFill(); NSBezierPath(ovalIn: disc).fill()
NSGraphicsContext.restoreGraphicsState()
// grooves
rgb(0xFFFFFF, 0.07).setStroke()
for r in stride(from: 300.0, to: 150.0, by: -22.0) {
    let p = NSBezierPath(ovalIn: NSRect(x: 512 - r, y: 512 - r, width: 2 * r, height: 2 * r)); p.lineWidth = 3; p.stroke()
}
// sheen
let sheen = NSBezierPath(); sheen.move(to: center)
sheen.appendArc(withCenter: center, radius: 315, startAngle: 40, endAngle: 70)
sheen.close(); rgb(0xFFFFFF, 0.10).setFill(); sheen.fill()
// label + pause
rgb(0xFFF4EC).setFill(); NSBezierPath(ovalIn: NSRect(x: 382, y: 382, width: 260, height: 260)).fill()
rgb(accent).setFill()
for dx: CGFloat in [-(15 + 36), 15] {
    NSBezierPath(roundedRect: NSRect(x: 512 + dx, y: 452, width: 36, height: 120), xRadius: 11, yRadius: 11).fill()
}
NSGraphicsContext.restoreGraphicsState()

// faint top highlight
NSGraphicsContext.saveGraphicsState(); squircle.addClip()
NSGradient(starting: rgb(0xFFFFFF, 0.14), ending: rgb(0xFFFFFF, 0))!.draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
