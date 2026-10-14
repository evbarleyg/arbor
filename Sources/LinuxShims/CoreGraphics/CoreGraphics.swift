// Linux has no CoreGraphics, but its Foundation has the geometry types Arbor uses: `CGRect`,
// `CGPoint`, `CGSize` and `CGFloat`. This module stands in for CoreGraphics there (Package.swift
// declares it only off macOS), so the headless code says `import CoreGraphics` on every platform.
//
// On macOS that import cannot be replaced by Foundation: Foundation brings the types, but their
// members (`minX`, `==`…) come from CoreGraphics.
//
// This passes on all of Foundation, which the real CoreGraphics does not (re-exporting only the four
// types is not possible), so a file that forgets `import Foundation` compiles here and fails on
// macOS. scripts/lint-imports.py, part of `make check`, looks for such files.
//
// Nothing else of CoreGraphics exists here. Code that needs more (`CGEvent`, `CGWindowList…`) belongs
// in ArborKit's macOS-only folders.
@_exported import Foundation
