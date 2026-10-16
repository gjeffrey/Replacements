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

let blue = color(0.035, 0.39, 0.98)
let ink = color(0.10, 0.16, 0.24)
let highlight = NSBezierPath(roundedRect: NSRect(x: 205, y: 399, width: 258, height: 226), xRadius: 10, yRadius: 10)
color(0.78, 0.87, 1).setFill(); highlight.fill()

// Two characters use the actual system font, optically centered in their selection.
let font = NSFont.systemFont(ofSize: 160, weight: .semibold)
let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
let string = "ab" as NSString
let bounds = string.size(withAttributes: attributes)
string.draw(at: NSPoint(x: 334 - bounds.width / 2, y: 519 - bounds.height / 2), withAttributes: attributes)

// A pair of deliberately oversized selection handles forms a strong Dock silhouette.
blue.setFill()
NSBezierPath(roundedRect: NSRect(x: 198, y: 399, width: 14, height: 272), xRadius: 7, yRadius: 7).fill()
NSBezierPath(ovalIn: NSRect(x: 181, y: 647, width: 48, height: 48)).fill()
NSBezierPath(roundedRect: NSRect(x: 456, y: 353, width: 14, height: 272), xRadius: 7, yRadius: 7).fill()
NSBezierPath(ovalIn: NSRect(x: 439, y: 329, width: 48, height: 48)).fill()

// The short selection opens into three word strokes; no sentence has to be read.
for (y, width) in [(CGFloat(579), CGFloat(300)), (CGFloat(489), CGFloat(244)), (CGFloat(399), CGFloat(280))] {
    let word = NSBezierPath(roundedRect: NSRect(x: 530, y: y, width: width, height: 45), xRadius: 11, yRadius: 11)
    ink.setFill(); word.fill()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
print("Rendered Replacements Selection icon with \(font.fontName).")
