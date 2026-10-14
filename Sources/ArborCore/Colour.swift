import Foundation

/// A colour in sRGB with straight (not premultiplied) alpha, every component from 0 to 1. Arbor
/// chooses its colours with this type, where tests can check the choices; the UI only turns the
/// result into an `NSColor`.
public struct RGBA: Equatable, Hashable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double
  public var alpha: Double

  /// Components outside 0...1 are clamped; anything that is not a number counts as 0.
  public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
    func component(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0 }
    self.red = component(red)
    self.green = component(green)
    self.blue = component(blue)
    self.alpha = component(alpha)
  }

  public init(white: Double, alpha: Double = 1) {
    self.init(red: white, green: white, blue: white, alpha: alpha)
  }

  public static let black = RGBA(white: 0)
  public static let white = RGBA(white: 1)

  public func withAlpha(_ alpha: Double) -> RGBA {
    RGBA(red: red, green: green, blue: blue, alpha: alpha)
  }

  /// This colour with `amount` (0...1) of `other` mixed in, component by component.
  public func mixed(with other: RGBA, amount: Double) -> RGBA {
    let t = amount.isFinite ? min(max(amount, 0), 1) : 0
    func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
    return RGBA(
      red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue),
      alpha: mix(alpha, other.alpha))
  }

  /// What is seen when this colour, as translucent as it is, lies over `other`: one colour that does to whatever is
  /// behind the two what they do together.
  public func over(_ other: RGBA) -> RGBA {
    let covered = other.alpha * (1 - alpha)
    let total = alpha + covered
    guard total > 0 else { return RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
    func blend(_ a: Double, _ b: Double) -> Double { (a * alpha + b * covered) / total }
    return RGBA(
      red: blend(red, other.red), green: blend(green, other.green), blue: blend(blue, other.blue), alpha: total)
  }

  /// How light the colour looks, from 0 (black) to 1 (white): WCAG's relative luminance. Alpha is ignored.
  public var luminance: Double {
    func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  /// WCAG's contrast ratio between two opaque colours, from 1 (the same) to 21 (black on white).
  public func contrast(with other: RGBA) -> Double {
    let lighter = max(luminance, other.luminance)
    let darker = min(luminance, other.luminance)
    return (lighter + 0.05) / (darker + 0.05)
  }

  /// Black or white, whichever reads better on this colour. White text on a pale app colour cannot be
  /// read, and neither can black on a dark one. The better of the two always reaches 4.5 to 1, on a colour of
  /// middling lightness only just (`TilePalette` sees to those).
  public var ink: RGBA {
    contrast(with: .black) >= contrast(with: .white) ? .black : .white
  }
}

/// The colour an app is recognised by, taken from its icon.
public enum IconColour {
  /// Hues are counted in this many equal slices of the colour wheel.
  private static let slices = 12

  /// The most prominent vivid colour among `samples` (an icon's pixels, in any order), or nil if
  /// they are all transparent.
  ///
  /// The plain average will not do. Many icons are a white tile with a coloured glyph, which averages
  /// to almost white, and the average of a many-coloured icon is mud. So pixels vote for their hue
  /// with the strength of their colour, and the winning hue's pixels are averaged. An icon with
  /// hardly any colour in it (a terminal, a text editor) gets the average after all: its grey.
  public static func dominant(of samples: [RGBA]) -> RGBA? {
    var votes = [Double](repeating: 0, count: slices)
    var sums = [(red: Double, green: Double, blue: Double)](repeating: (0, 0, 0), count: slices)
    var coverage = 0.0
    var plain = (red: 0.0, green: 0.0, blue: 0.0)

    for sample in samples where sample.alpha > 0 {
      coverage += sample.alpha
      plain.red += sample.red * sample.alpha
      plain.green += sample.green * sample.alpha
      plain.blue += sample.blue * sample.alpha

      let high = max(sample.red, sample.green, sample.blue)
      let chroma = high - min(sample.red, sample.green, sample.blue)
      guard chroma > 0.08 else { continue }  // Greys have no hue worth counting.
      var hue: Double  // 0..<6, one unit per 60°
      if high == sample.red {
        hue = (sample.green - sample.blue) / chroma
        if hue < 0 { hue += 6 }
      } else if high == sample.green {
        hue = (sample.blue - sample.red) / chroma + 2
      } else {
        hue = (sample.red - sample.green) / chroma + 4
      }
      let slice = min(Int(hue / 6 * Double(slices)), slices - 1)
      let weight = sample.alpha * chroma
      votes[slice] += weight
      sums[slice].red += sample.red * weight
      sums[slice].green += sample.green * weight
      sums[slice].blue += sample.blue * weight
    }

    guard coverage > 0 else { return nil }
    guard votes.reduce(0, +) >= 0.05 * coverage else {
      return RGBA(red: plain.red / coverage, green: plain.green / coverage, blue: plain.blue / coverage)
    }

    // A hue on the border between two slices splits its votes, so neighbours count for half.
    func neighbours(of slice: Int) -> [Int] { [(slice + slices - 1) % slices, (slice + 1) % slices] }
    func score(_ slice: Int) -> Double {
      votes[slice] + neighbours(of: slice).map { votes[$0] }.reduce(0, +) / 2
    }
    var winner = 0
    for slice in 1..<slices where score(slice) > score(winner) { winner = slice }
    var total = 0.0
    var sum = (red: 0.0, green: 0.0, blue: 0.0)
    for slice in [winner] + neighbours(of: winner) {
      total += votes[slice]
      sum.red += sums[slice].red
      sum.green += sums[slice].green
      sum.blue += sums[slice].blue
    }
    return RGBA(red: sum.red / total, green: sum.green / total, blue: sum.blue / total)
  }
}
