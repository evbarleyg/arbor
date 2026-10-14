// Draws Arbor's app icon at every size macOS asks for.
//
//   swift scripts/make-icon.swift build/Arbor.iconset
//   iconutil -c icns build/Arbor.iconset -o build/Arbor.icns
//
// scripts/bundle.sh runs both. The icon is a rounded square with a deep green gradient and Arbor's mark in
// white: a split layout that grows like a tree. The right column is whole (the trunk), the left
// column is split in two (a branch), and its upper half is split again (two leaves).
//
// A script cannot import the package, so `cells` repeats `ArborGlyph.cells` (Sources/ArborCore/ArborGlyph.swift)
// and the colours and proportions repeat `ArborArtwork.appIcon` (Sources/ArborKit/UI/ArborArtwork.swift),
// which draws the same picture for Arbor's own windows. Keep the three in step.

import CoreGraphics
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("make-icon: \(message)\n".utf8))
  exit(1)
}

/// The mark's rectangles inside `rect`, `gap` apart, with y growing upward: the trunk, the branch, then the leaves.
func cells(in rect: CGRect, gap: CGFloat, leaves: Bool) -> [CGRect] {
  let leafWidth = max((((rect.width - gap) * 0.54 - gap) / 2).rounded(), 0)
  let leftWidth = leafWidth * 2 + gap
  let leafHeight = max(((rect.height - gap) * 0.44).rounded(), 0)
  let leafY = rect.maxY - leafHeight
  var cells = [
    CGRect(x: rect.minX + leftWidth + gap, y: rect.minY, width: rect.width - leftWidth - gap, height: rect.height),
    CGRect(x: rect.minX, y: rect.minY, width: leftWidth, height: rect.height - gap - leafHeight),
  ]
  if leaves {
    cells.append(CGRect(x: rect.minX, y: leafY, width: leafWidth, height: leafHeight))
    cells.append(CGRect(x: rect.minX + leafWidth + gap, y: leafY, width: leafWidth, height: leafHeight))
  } else {
    cells.append(CGRect(x: rect.minX, y: leafY, width: leftWidth, height: leafHeight))
  }
  return cells
}

let opacities: [CGFloat] = [1, 0.92, 0.8, 0.68]

func icon(pixels: Int) -> CGImage {
  guard let space = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
      data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { fail("no bitmap of \(pixels) pixels") }
  let side = CGFloat(pixels)
  let top = CGColor(srgbRed: 0.18, green: 0.63, blue: 0.38, alpha: 1)
  let bottom = CGColor(srgbRed: 0.04, green: 0.29, blue: 0.20, alpha: 1)

  // Apple's grid for macOS icons: the shape takes 824 of 1024 points, with a corner radius of 185.4 and a soft
  // shadow below it.
  let shape = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: side * 100 / 1024, dy: side * 100 / 1024)
  let radius = shape.width * 185.4 / 824
  let outline = CGPath(roundedRect: shape, cornerWidth: radius, cornerHeight: radius, transform: nil)

  context.saveGState()
  context.setShadow(
    offset: CGSize(width: 0, height: -side * 10 / 1024), blur: side * 20 / 1024, color: CGColor(gray: 0, alpha: 0.3))
  context.addPath(outline)
  context.setFillColor(bottom)
  context.fillPath()
  context.restoreGState()

  guard let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) else {
    fail("no gradient")
  }
  context.saveGState()
  context.addPath(outline)
  context.clip()
  context.drawLinearGradient(
    gradient, start: CGPoint(x: 0, y: shape.maxY), end: CGPoint(x: 0, y: shape.minY), options: [])
  context.restoreGState()

  // Below 64 pixels two leaves would be specks: one leaf, and a slightly larger mark.
  let detailed = pixels >= 64
  let markSide = (shape.width * (detailed ? 0.58 : 0.64)).rounded()
  let mark = CGRect(
    x: ((side - markSide) / 2).rounded(), y: ((side - markSide) / 2).rounded(), width: markSide, height: markSide)
  let gap = max((markSide * 0.07).rounded(), 1)
  let corner = markSide * 0.045
  for (cell, opacity) in zip(cells(in: mark, gap: gap, leaves: detailed), opacities) {
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity))
    context.addPath(CGPath(roundedRect: cell, cornerWidth: corner, cornerHeight: corner, transform: nil))
    context.fillPath()
  }

  guard let image = context.makeImage() else { fail("no image of \(pixels) pixels") }
  return image
}

guard CommandLine.arguments.count == 2 else { fail("usage: swift scripts/make-icon.swift <folder>.iconset") }
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
do {
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
} catch {
  fail("cannot create \(folder.path): \(error)")
}

for points in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
    let url = folder.appendingPathComponent(name)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
      fail("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(destination, icon(pixels: points * scale), nil)
    guard CGImageDestinationFinalize(destination) else { fail("cannot write \(url.path)") }
  }
}
print("drew \(folder.path)")
