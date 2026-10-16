#!/usr/bin/env swift
// Original substitution artwork rendered entirely from AppKit paths.
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
// Two short character strokes become three longer word strokes.
blue.setFill()
for (x, width) in [(CGFloat(232), CGFloat(78)), (CGFloat(350), CGFloat(96))] {
    NSBezierPath(roundedRect: NSRect(x: x, y: 638, width: width, height: 52), xRadius: 12, yRadius: 12).fill()
}
ink.setFill()
for (x, width) in [(CGFloat(232), CGFloat(128)), (CGFloat(398), CGFloat(176)), (CGFloat(612), CGFloat(178))] {
    NSBezierPath(roundedRect: NSRect(x: x, y: 350, width: width, height: 52), xRadius: 12, yRadius: 12).fill()
}
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 510, y: 664))
arrow.curve(to: NSPoint(x: 778, y: 530), controlPoint1: NSPoint(x: 735, y: 664), controlPoint2: NSPoint(x: 778, y: 607))
arrow.curve(to: NSPoint(x: 730, y: 450), controlPoint1: NSPoint(x: 778, y: 480), controlPoint2: NSPoint(x: 730, y: 493))
arrow.move(to: NSPoint(x: 693, y: 487))
arrow.line(to: NSPoint(x: 730, y: 450))
arrow.line(to: NSPoint(x: 767, y: 487))
arrow.lineWidth = 18; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
blue.setStroke(); arrow.stroke()

NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
print("Rendered Replacements substitution icon.")
