import ArborCore
import Testing

@Suite struct ColourTests {
  @Test func componentsAreKeptBetweenZeroAndOne() {
    let colour = RGBA(red: -1, green: 2, blue: .nan, alpha: .infinity)
    #expect(colour == RGBA(red: 0, green: 1, blue: 0, alpha: 0))
    #expect(RGBA(white: 0.5) == RGBA(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
  }

  @Test func mixingMovesEveryComponentByTheAmount() {
    let grey = RGBA(white: 0.2)
    let blue = RGBA(red: 0, green: 0.4, blue: 1)
    #expect(grey.mixed(with: blue, amount: 0) == grey)
    #expect(grey.mixed(with: blue, amount: 1) == blue)
    let quarter = grey.mixed(with: blue, amount: 0.25)
    #expect(abs(quarter.red - 0.15) < 1e-9 && abs(quarter.green - 0.25) < 1e-9 && abs(quarter.blue - 0.4) < 1e-9)
    #expect(grey.mixed(with: blue, amount: 7) == blue)
    #expect(grey.mixed(with: blue, amount: -7) == grey)
    #expect(grey.mixed(with: blue, amount: .nan) == grey)
  }

  @Test func oneTranslucentColourOverAnotherIsOneColour() {
    let red = RGBA(red: 1, green: 0, blue: 0)
    let blue = RGBA(red: 0, green: 0, blue: 1)
    #expect(red.over(blue) == red, "an opaque colour hides what is under it")
    #expect(red.withAlpha(0).over(blue.withAlpha(0.3)) == blue.withAlpha(0.3), "a clear one changes nothing")
    #expect(red.withAlpha(0.3).over(blue.withAlpha(0)) == red.withAlpha(0.3))
    #expect(red.withAlpha(0).over(blue.withAlpha(0)).alpha == 0)

    // Laid over white, the one colour gives what the two give one after the other.
    func onWhite(_ colour: RGBA) -> RGBA { RGBA.white.mixed(with: colour.withAlpha(1), amount: colour.alpha) }
    let top = red.withAlpha(0.4), bottom = blue.withAlpha(0.6)
    let together = onWhite(top.over(bottom))
    let inTurn = onWhite(bottom).mixed(with: red, amount: 0.4)
    #expect(abs(together.red - inTurn.red) < 1e-9 && abs(together.green - inTurn.green) < 1e-9)
    #expect(abs(together.blue - inTurn.blue) < 1e-9)
  }

  @Test func luminanceRunsFromBlackToWhiteAndWeighsGreenMost() {
    #expect(RGBA.black.luminance == 0)
    #expect(abs(RGBA.white.luminance - 1) < 1e-9)
    #expect(abs(RGBA(white: 0.5).luminance - 0.2140) < 0.001)
    let red = RGBA(red: 1, green: 0, blue: 0).luminance
    let green = RGBA(red: 0, green: 1, blue: 0).luminance
    let blue = RGBA(red: 0, green: 0, blue: 1).luminance
    #expect(green > red && red > blue)
    #expect(abs(RGBA.black.contrast(with: .white) - 21) < 1e-9)
    #expect(RGBA.white.contrast(with: .black) == RGBA.black.contrast(with: .white))
  }

  @Test func inkIsBlackOnPaleColoursAndWhiteOnDeepOnes() {
    #expect(RGBA.white.ink == .black)
    #expect(RGBA(red: 0.99, green: 0.93, blue: 0.65).ink == .black, "the yellow of a notes app")
    #expect(RGBA(red: 0.75, green: 0.90, blue: 0.80).ink == .black)
    #expect(RGBA.black.ink == .white)
    #expect(RGBA(red: 0.10, green: 0.15, blue: 0.40).ink == .white, "navy")
    #expect(RGBA(red: 0.35, green: 0.10, blue: 0.40).ink == .white, "aubergine")
  }

  @Test func inkCanBeReadOnEveryColour() {
    let steps = stride(from: 0.0, through: 1.0, by: 0.05)
    for red in steps {
      for green in steps {
        for blue in steps {
          let colour = RGBA(red: red, green: green, blue: blue)
          #expect(colour.ink.contrast(with: colour) >= 4.5, "\(colour)")
        }
      }
    }
  }
}

@Suite struct IconColourTests {
  let red = RGBA(red: 0.9, green: 0.15, blue: 0.1)
  let blue = RGBA(red: 0.1, green: 0.4, blue: 0.95)
  let green = RGBA(red: 0.2, green: 0.8, blue: 0.3)
  let clear = RGBA(white: 1, alpha: 0)

  func samples(_ parts: (RGBA, Int)...) -> [RGBA] {
    parts.flatMap { Array(repeating: $0.0, count: $0.1) }
  }

  func isClose(_ a: RGBA?, _ b: RGBA, tolerance: Double = 0.02) -> Bool {
    guard let a else { return false }
    return abs(a.red - b.red) <= tolerance && abs(a.green - b.green) <= tolerance && abs(a.blue - b.blue) <= tolerance
  }

  @Test func aWhiteTileWithARedGlyphIsRedNotPink() {
    // The plain average would be (0.99, 0.92, 0.91).
    #expect(isClose(IconColour.dominant(of: samples((.white, 90), (red, 10))), red))
  }

  @Test func aManyColouredIconTakesItsLargestColourNotTheirMixture() {
    #expect(isClose(IconColour.dominant(of: samples((red, 20), (blue, 45), (green, 25), (.white, 10))), blue))
  }

  @Test func shadesOfOneHueAreAveraged() throws {
    let light = RGBA(red: 0.4, green: 0.6, blue: 1)
    let deep = RGBA(red: 0, green: 0.2, blue: 0.8)
    let colour = try #require(IconColour.dominant(of: samples((light, 50), (deep, 50))))
    #expect(colour.blue > colour.green && colour.green > colour.red)
    #expect(colour.blue > 0.8 && colour.blue < 1)
  }

  @Test func anIconWithHardlyAnyColourGetsItsGrey() {
    let dark = RGBA(white: 0.1)
    let colour = IconColour.dominant(of: samples((dark, 80), (.white, 18), (green, 2)))
    #expect(isClose(colour, RGBA(white: 0.27), tolerance: 0.03))
  }

  @Test func inAGreyIconFaintPixelsWeighLittle() {
    // A dark glyph with a wide, faint, white glow: the glow is a tenth as strong as it is large.
    let colour = IconColour.dominant(of: samples((RGBA(white: 0.2), 50), (RGBA.white.withAlpha(0.1), 50)))
    #expect(isClose(colour, RGBA(white: (0.2 + 0.1) / 1.1), tolerance: 0.01))
  }

  @Test func theLargerOfTwoColoursWinsWhereverItLiesOnTheColourWheel() {
    // Pure red is where the wheel begins and ends.
    let pure = RGBA(red: 1, green: 0, blue: 0)
    #expect(isClose(IconColour.dominant(of: samples((pure, 100), (blue, 70))), pure))
    #expect(isClose(IconColour.dominant(of: samples((pure, 70), (blue, 100))), blue))
  }

  @Test func orangeAndCrimsonAreTwoColoursThoughBothAreMostlyRed() {
    let orange = RGBA(red: 1, green: 0.5, blue: 0)
    let crimson = RGBA(red: 1, green: 0, blue: 0.3)
    #expect(isClose(IconColour.dominant(of: samples((orange, 50), (crimson, 40))), orange))
    #expect(isClose(IconColour.dominant(of: samples((orange, 40), (crimson, 50))), crimson))
  }

  @Test func transparentPixelsDoNotCount() {
    #expect(isClose(IconColour.dominant(of: samples((clear, 500), (blue, 5))), blue))
    // Half-transparent pixels count for half: 30 of these weigh less than 20 solid ones.
    #expect(isClose(IconColour.dominant(of: samples((red.withAlpha(0.5), 30), (blue, 20))), blue))
  }

  @Test func nothingVisibleHasNoColour() {
    #expect(IconColour.dominant(of: []) == nil)
    #expect(IconColour.dominant(of: samples((clear, 64))) == nil)
  }

  @Test func theOrderOfThePixelsDoesNotMatter() {
    let pixels = samples((red, 30), (blue, 31), (.white, 12))
    #expect(IconColour.dominant(of: pixels) == IconColour.dominant(of: pixels.reversed()))
  }
}
