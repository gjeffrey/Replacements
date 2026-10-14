#!/usr/bin/env swift
// Original artwork rendered from paths and macOS's San Francisco system font.
// This creates the complete icon; it does not modify a generated bitmap.
import AppKit

guard CommandLine.arguments.count == 2 else { fatalError("Usage: render-icon.swift <output.png>") }
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
}
// A continuous-corner tile, drawn as a single clean path with transparent outer margins.
let tile = NSBezierPath()
tile.move(to: NSPoint(x: 322, y: 942))
tile.line(to: NSPoint(x: 702, y: 942))
tile.curve(to: NSPoint(x: 942, y: 702), controlPoint1: NSPoint(x: 882, y: 942), controlPoint2: NSPoint(x: 942, y: 882))
tile.line(to: NSPoint(x: 942, y: 322))
tile.curve(to: NSPoint(x: 702, y: 82), controlPoint1: NSPoint(x: 942, y: 142), controlPoint2: NSPoint(x: 882, y: 82))
tile.line(to: NSPoint(x: 322, y: 82))
tile.curve(to: NSPoint(x: 82, y: 322), controlPoint1: NSPoint(x: 142, y: 82), controlPoint2: NSPoint(x: 82, y: 142))
tile.line(to: NSPoint(x: 82, y: 702))
tile.curve(to: NSPoint(x: 322, y: 942), controlPoint1: NSPoint(x: 82, y: 882), controlPoint2: NSPoint(x: 142, y: 942))
tile.close()
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.13)
shadow.shadowBlurRadius = 12
shadow.shadowOffset = NSSize(width: 0, height: -6)
shadow.set()
NSColor.white.setFill(); tile.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0.91, 0.93, 0.96), ending: color(0.998, 0.998, 1))!.draw(in: tile, angle: 90)
tile.lineWidth = 1.5
NSColor.white.withAlphaComponent(0.85).setStroke(); tile.stroke()

let blue = color(0.035, 0.36, 0.96)
let ink = color(0.08, 0.19, 0.34)
let pill = NSBezierPath(roundedRect: NSRect(x: 292, y: 628, width: 440, height: 176), xRadius: 58, yRadius: 58)
NSGraphicsContext.saveGraphicsState()
let pillShadow = NSShadow()
pillShadow.shadowColor = blue.withAlphaComponent(0.16)
pillShadow.shadowBlurRadius = 10
pillShadow.shadowOffset = NSSize(width: 0, height: -5)
pillShadow.set(); blue.setFill(); pill.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0.04, 0.32, 0.91), ending: color(0.07, 0.44, 1))!.draw(in: pill, angle: 90)

func text(_ value: String, centeredAtY y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let string = value as NSString
    let bounds = string.size(withAttributes: attributes)
    string.draw(at: NSPoint(x: (1024 - bounds.width) / 2, y: y - bounds.height / 2), withAttributes: attributes)
}
text("brb", centeredAtY: 725, size: 132, weight: .semibold, color: .white)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 512, y: 568))
arrow.line(to: NSPoint(x: 512, y: 486))
arrow.move(to: NSPoint(x: 476, y: 522))
arrow.line(to: NSPoint(x: 512, y: 486))
arrow.line(to: NSPoint(x: 548, y: 522))
arrow.lineWidth = 15; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
blue.setStroke(); arrow.stroke()

text("be right", centeredAtY: 377, size: 116, weight: .semibold, color: ink)
text("back", centeredAtY: 247, size: 116, weight: .semibold, color: ink)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
print("Rendered 1024px original icon with \(NSFont.systemFont(ofSize: 116, weight: .semibold).fontName).")
