import AppKit

// Renders the Murmur app icon: a soft white tile with an ink waveform and a coral dot.
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

let inset: CGFloat = size * 0.09
let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
                        xRadius: size * 0.2, yRadius: size * 0.2)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.06, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor(white: 0.985, alpha: 1).setFill()
tile.fill()
ctx.restoreGState()
NSColor(white: 0, alpha: 0.05).setStroke()
tile.lineWidth = size * 0.004
tile.stroke()

// Waveform bars, mirrored about the centre line.
let heights: [CGFloat] = [0.16, 0.34, 0.62, 0.44, 0.84, 0.56, 0.30, 0.18]
let barW = size * 0.052
let gap = size * 0.038
let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
var x = (size - totalW) / 2
let maxH = size * 0.46
NSColor(white: 0.08, alpha: 1).setFill()
for h in heights {
    let barH = maxH * h
    let rect = NSRect(x: x, y: size / 2 - barH / 2, width: barW, height: barH)
    NSBezierPath(roundedRect: rect, xRadius: barW / 2, yRadius: barW / 2).fill()
    x += barW + gap
}
// The accent dot.
NSColor(red: 1.0, green: 0.31, blue: 0.13, alpha: 1).setFill()
let dot = size * 0.06
NSBezierPath(ovalIn: NSRect(x: size - inset - dot * 1.9, y: size - inset - dot * 1.9, width: dot, height: dot)).fill()
image.unlockFocus()

let out = CommandLine.arguments[1]
let tiff = image.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
