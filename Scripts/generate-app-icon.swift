#!/usr/bin/env swift
// Deterministic placeholder icon generator for Portero.app.
//
// Draws pure NSBezierPath geometry into NSBitmapImageRep — no font, no
// SF Symbol lookup, no ImageMagick — so the result is reproducible across
// machines using only the Swift toolchain and Command Line Tools.
//
// Usage: swift Scripts/generate-app-icon.swift
// Produces: build/AppIcon.iconset/*.png, then Resources/AppIcon.icns
//
// See openspec/changes/arreglar-icono-app/design.md, "Placeholder Artwork
// Spec", for the exact geometry this script implements.

import AppKit
import Foundation

// MARK: - Artwork constants (design.md Placeholder Artwork Spec)

let canvasSize: CGFloat = 1024
let plateSize: CGFloat = 824
let plateCornerRadius: CGFloat = 185.4
let plateColor = NSColor(srgbRed: 0x1E / 255.0, green: 0x5F / 255.0, blue: 0x74 / 255.0, alpha: 1.0)

let doorWidthFraction: CGFloat = 0.34
let doorHeightFraction: CGFloat = 0.58
let doorCornerRadius: CGFloat = 24
let doorColor = NSColor.white

let knobRadiusFraction: CGFloat = 0.03 // of plate size
let knobHorizontalFraction: CGFloat = 0.72 // of door width, from door's left edge

// MARK: - Iconset sizes (exact iconutil naming)

struct IconsetMember {
    let fileName: String
    let pixelSize: CGFloat
}

let iconsetMembers: [IconsetMember] = [
    IconsetMember(fileName: "icon_16x16.png", pixelSize: 16),
    IconsetMember(fileName: "icon_16x16@2x.png", pixelSize: 32),
    IconsetMember(fileName: "icon_32x32.png", pixelSize: 32),
    IconsetMember(fileName: "icon_32x32@2x.png", pixelSize: 64),
    IconsetMember(fileName: "icon_128x128.png", pixelSize: 128),
    IconsetMember(fileName: "icon_128x128@2x.png", pixelSize: 256),
    IconsetMember(fileName: "icon_256x256.png", pixelSize: 256),
    IconsetMember(fileName: "icon_256x256@2x.png", pixelSize: 512),
    IconsetMember(fileName: "icon_512x512.png", pixelSize: 512),
    IconsetMember(fileName: "icon_512x512@2x.png", pixelSize: 1024),
]

// MARK: - Drawing

/// Draws the placeholder glyph at `pixelSize` (native resolution — the vector
/// geometry is scaled by drawing into a bitmap of exactly this size, never
/// resampled from a larger render).
func drawIcon(pixelSize: CGFloat) -> NSBitmapImageRep {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize),
            pixelsHigh: Int(pixelSize),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        fatalError("Failed to allocate NSBitmapImageRep for size \(pixelSize)")
    }

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Failed to create NSGraphicsContext for size \(pixelSize)")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    // Scale factor from the 1024x1024 design canvas to this pixel size.
    let scale = pixelSize / canvasSize

    // Plate: centered, filled rounded rect.
    let plateOrigin = (canvasSize - plateSize) / 2 * scale
    let plateRect = NSRect(x: plateOrigin, y: plateOrigin, width: plateSize * scale, height: plateSize * scale)
    let platePath = NSBezierPath(roundedRect: plateRect, xRadius: plateCornerRadius * scale, yRadius: plateCornerRadius * scale)
    plateColor.setFill()
    platePath.fill()

    // Door: centered white rounded rect over the plate.
    let doorWidth = plateSize * doorWidthFraction * scale
    let doorHeight = plateSize * doorHeightFraction * scale
    let doorOriginX = (canvasSize * scale - doorWidth) / 2
    let doorOriginY = (canvasSize * scale - doorHeight) / 2
    let doorRect = NSRect(x: doorOriginX, y: doorOriginY, width: doorWidth, height: doorHeight)
    let doorPath = NSBezierPath(roundedRect: doorRect, xRadius: doorCornerRadius * scale, yRadius: doorCornerRadius * scale)
    doorColor.setFill()
    doorPath.fill()

    // Knob: filled circle on the door, at knobHorizontalFraction of the door
    // width from its left edge, vertically centered.
    let knobRadius = plateSize * knobRadiusFraction * scale
    let knobCenterX = doorOriginX + doorWidth * knobHorizontalFraction
    let knobCenterY = doorOriginY + doorHeight / 2
    let knobRect = NSRect(
        x: knobCenterX - knobRadius,
        y: knobCenterY - knobRadius,
        width: knobRadius * 2,
        height: knobRadius * 2
    )
    let knobPath = NSBezierPath(ovalIn: knobRect)
    plateColor.setFill()
    knobPath.fill()

    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(url.path)")
    }
    try pngData.write(to: url)
}

// MARK: - Main

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconsetDir = repoRoot.appendingPathComponent("build/AppIcon.iconset")
let resourcesDir = repoRoot.appendingPathComponent("Resources")
let icnsPath = resourcesDir.appendingPathComponent("AppIcon.icns")

try? fileManager.removeItem(at: iconsetDir)
try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for member in iconsetMembers {
    let bitmap = drawIcon(pixelSize: member.pixelSize)
    let destination = iconsetDir.appendingPathComponent(member.fileName)
    try writePNG(bitmap, to: destination)
    print("Wrote \(member.fileName) (\(Int(member.pixelSize))x\(Int(member.pixelSize)))")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with exit code \(process.terminationStatus)")
}

print("Wrote \(icnsPath.path)")
