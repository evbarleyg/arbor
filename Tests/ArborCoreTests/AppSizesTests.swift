import ArborCore
import CoreGraphics
import Foundation
import Testing

private let day: TimeInterval = 24 * 3600
private let morning = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// How small apps go, by bundle id (docs/features/F68-how-small-apps-go.md).
@Suite struct AppSizesTests {
  func size(_ width: CGFloat, _ height: CGFloat) -> CGSize { CGSize(width: width, height: height) }

  func knowing(_ app: String = "com.example.mail", _ width: CGFloat = 760, _ height: CGFloat = 400) -> AppSizes {
    var sizes = AppSizes()
    sizes.stoodBy(size(width, height), app: app, macOS: 26, at: morning)
    return sizes
  }

  // MARK: What a window answered

  @Test func whatAWindowStoodByIsKnownOfItsApp() {
    var sizes = AppSizes()
    #expect(sizes.entry(for: "com.example.mail") == nil)
    do {
      let changed = sizes.stoodBy(size(760, 400), app: "com.example.mail", macOS: 26, at: morning)
      #expect(changed)
    }
    #expect(sizes.entry(for: "com.example.mail") == .init(width: 760, height: 400, macOS: 26, seen: morning))
    #expect(sizes.entry(for: "com.example.notes") == nil)
  }

  @Test func aDirectionInWhichItDidAsAskedSaysNothing() {
    var sizes = AppSizes()
    sizes.stoodBy(size(760, 0), app: "com.example.mail", macOS: 26, at: morning)
    #expect(sizes.entry(for: "com.example.mail")?.size == size(760, 0))
    // Nor does it take away what is known.
    sizes.stoodBy(size(0, 400), app: "com.example.mail", macOS: 26, at: morning + 60)
    #expect(sizes.entry(for: "com.example.mail")?.size == size(760, 400))
  }

  /// One date for two numbers, and it is the older one's.
  @Test func theDateIsRenewedOnlyWhenAllThatIsKnownHasBeenStoodBy() {
    var sizes = knowing()
    sizes.stoodBy(size(0, 400), app: "com.example.mail", macOS: 26, at: morning + 60)
    #expect(sizes.entry(for: "com.example.mail")?.seen == morning, "nobody stood by the width")
    sizes.stoodBy(size(800, 0), app: "com.example.mail", macOS: 26, at: morning + 90)
    #expect(sizes.entry(for: "com.example.mail") == .init(width: 800, height: 400, macOS: 26, seen: morning), "nor by the height")
    sizes.stoodBy(size(800, 400), app: "com.example.mail", macOS: 26, at: morning + 120)
    #expect(sizes.entry(for: "com.example.mail")?.seen == morning + 120)
    // Where only one is known, that is all that is known.
    var narrow = AppSizes()
    narrow.stoodBy(size(760, 0), app: "com.example.mail", macOS: 26, at: morning)
    narrow.stoodBy(size(760, 0), app: "com.example.mail", macOS: 26, at: morning + 60)
    #expect(narrow.entry(for: "com.example.mail")?.seen == morning + 60)
    // What becomes known beside something older is as old as that: it goes with it, and is learned again.
    narrow.stoodBy(size(0, 400), app: "com.example.mail", macOS: 26, at: morning + 90)
    #expect(narrow.entry(for: "com.example.mail") == .init(width: 760, height: 400, macOS: 26, seen: morning + 60))
  }

  /// A window answered while it floated, and is docked weeks later.
  @Test func anAnswerOlderThanWhatIsKeptIsNoNews() {
    var sizes = knowing()
    sizes.stoodBy(size(760, 400), app: "com.example.mail", macOS: 26, at: morning + 20 * day)
    let changed = sizes.stoodBy(size(900, 500), app: "com.example.mail", macOS: 26, at: morning + day)
    #expect(!changed)
    #expect(sizes.entry(for: "com.example.mail") == .init(width: 760, height: 400, macOS: 26, seen: morning + 20 * day))
  }

  @Test func whatIsTooOldDoesNotComeBackToLifeWithTheOtherDirectionsAnswer() {
    var sizes = knowing()
    sizes.stoodBy(size(0, 380), app: "com.example.mail", macOS: 26, at: morning + 31 * day)
    #expect(sizes.entry(for: "com.example.mail") == .init(width: 0, height: 380, macOS: 26, seen: morning + 31 * day))
    sizes = knowing()
    sizes.stoodBy(size(0, 380), app: "com.example.mail", macOS: 27, at: morning + 1)
    #expect(sizes.entry(for: "com.example.mail") == .init(width: 0, height: 380, macOS: 27, seen: morning + 1))
  }

  @Test func whatWasJustSeenReplacesWhatWasKnownLargerOrSmaller() {
    var sizes = knowing()
    do {
      let changed = sizes.stoodBy(size(900, 0), app: "com.example.mail", macOS: 26, at: morning + 1)
      #expect(changed)
    }
    #expect(sizes.entry(for: "com.example.mail")?.size == size(900, 400))
    do {
      let changed = sizes.stoodBy(size(700, 380), app: "com.example.mail", macOS: 26, at: morning + 2)
      #expect(changed)
    }
    #expect(sizes.entry(for: "com.example.mail")?.size == size(700, 380))
  }

  @Test func theSameAnswerAtTheSameMomentIsNoNews() {
    var sizes = knowing()
    do {
      let changed = sizes.stoodBy(size(760, 400), app: "com.example.mail", macOS: 26, at: morning)
      #expect(!changed)
    }
    // Later it is: somebody has stood by it again.
    do {
      let changed = sizes.stoodBy(size(760, 400), app: "com.example.mail", macOS: 26, at: morning + day)
      #expect(changed)
    }
  }

  @Test(arguments: [
    CGSize.zero, CGSize(width: -1, height: 400), CGSize(width: CGFloat.infinity, height: 0), CGSize(width: CGFloat.nan, height: 10),
    CGSize(width: 10_001, height: 0), CGSize(width: 19, height: 0), CGSize(width: 760, height: 5),
  ]) func whatNoWindowCouldHaveAnsweredIsNotKept(answer: CGSize) {
    var sizes = AppSizes()
    do {
      let changed = sizes.stoodBy(answer, app: "com.example.mail", macOS: 26, at: morning)
      #expect(!changed)
    }
    #expect(sizes.isEmpty)
  }

  @Test func anAppWithoutANameIsNotKept() {
    var sizes = AppSizes()
    do {
      let changed = sizes.stoodBy(size(760, 400), app: "", macOS: 26, at: morning)
      #expect(!changed)
    }
    do {
      let changed = sizes.stoodBy(size(760, 400), app: String(repeating: "a", count: 256), macOS: 26, at: morning)
      #expect(!changed)
    }
    #expect(sizes.isEmpty)
  }

  // MARK: The ways out of a wrong record

  /// Not what was seen: nobody stood by that.
  @Test func aWindowSeenSmallerMakesThatDirectionUnknownAgain() {
    var sizes = knowing()
    do {
      let changed = sizes.wasSeen(at: size(600, 500), app: "com.example.mail")
      #expect(changed)
    }
    #expect(sizes.entry(for: "com.example.mail") == .init(width: 0, height: 400, macOS: 26, seen: morning))
    do {
      let changed = sizes.wasSeen(at: size(600, 300), app: "com.example.mail")
      #expect(changed)
    }
    #expect(sizes.isEmpty, "an app of which nothing is known is not kept")
  }

  @Test func aWindowAsLargeOrLargerSaysNothing() {
    var sizes = knowing()
    for seen in [size(760, 400), size(759, 399), size(758, 398), size(2000, 1200)] {
      do {
        let changed = sizes.wasSeen(at: seen, app: "com.example.mail")
        #expect(!changed)
      }
    }
    #expect(sizes == knowing())
  }

  @Test func whatIsNotKnownDoesNotComeDown() {
    var sizes = AppSizes()
    sizes.stoodBy(size(760, 0), app: "com.example.mail", macOS: 26, at: morning)
    do {
      let changed = sizes.wasSeen(at: size(800, 100), app: "com.example.mail")
      #expect(!changed)
    }
    do {
      let changed = sizes.wasSeen(at: size(100, 100), app: "com.example.notes")
      #expect(!changed)
    }
    #expect(sizes.entry(for: "com.example.mail")?.size == size(760, 0))
  }

  /// Some apps open a window a point wide and give it its size afterwards.
  @Test func aWindowWithNextToNoSizeIsComingOrGoingNotGoingSmall() {
    var sizes = knowing()
    for seen in [size(1, 1), size(19, 300), size(600, 19)] {
      let changed = sizes.wasSeen(at: seen, app: "com.example.mail")
      #expect(!changed)
    }
    let changed = sizes.wasSeen(at: size(20, 20), app: "com.example.mail")
    #expect(changed)
  }

  @Test func aWindowWithoutASizeIsGoingAwayNotGoingSmall() {
    var sizes = knowing()
    do {
      let changed = sizes.wasSeen(at: .zero, app: "com.example.mail")
      #expect(!changed)
    }
    do {
      let changed = sizes.wasSeen(at: size(0, 300), app: "com.example.mail")
      #expect(!changed)
    }
    #expect(sizes == knowing())
  }

  @Test func forgettingTakesTheAppsNamedAndNoOther() {
    var sizes = knowing()
    sizes.stoodBy(size(709, 300), app: "com.example.notes", macOS: 26, at: morning)
    do {
      let changed = sizes.drop(["com.example.mail", "com.example.unheard-of"])
      #expect(changed)
    }
    #expect(sizes.entry(for: "com.example.mail") == nil)
    #expect(sizes.entry(for: "com.example.notes") != nil)
    do {
      let changed = sizes.drop(["com.example.mail"])
      #expect(!changed)
    }
  }

  @Test func afterThirtyDaysByWhichNobodyStoodItIsGone() {
    var sizes = knowing()
    do {
      let changed = sizes.expire(at: morning + 30 * day - 1, macOS: 26)
      #expect(!changed)
    }
    #expect(sizes.entry(for: "com.example.mail") != nil)
    do {
      let changed = sizes.expire(at: morning + 30 * day, macOS: 26)
      #expect(changed)
    }
    #expect(sizes.isEmpty)
  }

  /// Arbor runs for weeks.
  @Test func whatIsTooOldIsNotGoneByEvenBeforeItIsDropped() {
    let sizes = knowing()
    #expect(sizes.entry(for: "com.example.mail", at: morning + 30 * day - 1, macOS: 26) != nil)
    #expect(sizes.entry(for: "com.example.mail", at: morning + 30 * day, macOS: 26) == nil)
    #expect(sizes.entry(for: "com.example.mail", at: morning - 30 * day, macOS: 26) == nil)
    #expect(sizes.entry(for: "com.example.mail", at: morning, macOS: 27) == nil)
    #expect(sizes.entry(for: "com.example.mail") != nil)
  }

  @Test func forAReplayItIsAsOldAsItWasOnTheReplaysOwnClockAndSystem() {
    let moved = knowing().moved(by: -1000, macOS: 6)
    #expect(moved.entry(for: "com.example.mail") == .init(width: 760, height: 400, macOS: 6, seen: morning - 1000))
  }

  @Test func standingByItAgainStartsTheThirtyDaysAgain() {
    var sizes = knowing()
    sizes.stoodBy(size(760, 400), app: "com.example.mail", macOS: 26, at: morning + 20 * day)
    do {
      let changed = sizes.expire(at: morning + 45 * day, macOS: 26)
      #expect(!changed)
    }
  }

  @Test func aDateFromAClockThatRanAheadDoesNotLiveForEver() {
    var sizes = AppSizes()
    sizes.stoodBy(size(760, 400), app: "com.example.mail", macOS: 26, at: morning + 400 * day)
    do {
      let changed = sizes.expire(at: morning, macOS: 26)
      #expect(changed)
    }
  }

  @Test func whatWasSeenOnAnotherMacOSIsGone() {
    var sizes = knowing()
    sizes.stoodBy(size(709, 300), app: "com.example.notes", macOS: 15, at: morning)
    do {
      let changed = sizes.expire(at: morning + 1, macOS: 26)
      #expect(changed)
    }
    #expect(sizes.apps.keys.sorted() == ["com.example.mail"])
  }

  @Test func theOldestGoWhenThereAreTooMany() {
    var sizes = AppSizes()
    for index in 0..<(AppSizes.capacity + 10) {
      sizes.stoodBy(size(500, 300), app: "com.example.app\(index)", macOS: 26, at: morning + Double(index))
    }
    #expect(sizes.apps.count == AppSizes.capacity)
    #expect(sizes.entry(for: "com.example.app9") == nil)
    #expect(sizes.entry(for: "com.example.app10") != nil)
    #expect(sizes.entry(for: "com.example.app\(AppSizes.capacity + 9)") != nil)
  }

  // MARK: On disk

  @Test func itComesBackFromAFileAsItWent() throws {
    var sizes = knowing()
    sizes.stoodBy(size(709.5, 0), app: "com.example.notes", macOS: 26, at: morning + 0.25)
    let read = try JSONDecoder().decode(AppSizes.self, from: JSONEncoder().encode(sizes))
    #expect(read == sizes)
  }

  /// A bundle id, two numbers, the version of macOS and a date, and nothing else: whoever adds to this has read the product owner's
  /// decision in `collab/QUESTIONS.md` first.
  @Test func nothingIsWrittenButTheAppTwoNumbersTheVersionAndADate() throws {
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(knowing())) as? [String: [String: Any]]
    #expect(object?.keys.sorted() == ["com.example.mail"])
    #expect(object?["com.example.mail"]?.keys.sorted() == ["height", "macOS", "seen", "width"])
    for value in (object?["com.example.mail"] ?? [:]).values { #expect(value is NSNumber) }
  }

  @Test(arguments: [
    #"{"width":"wide","height":400,"macOS":26,"seen":1}"#, #"{"height":400,"macOS":26,"seen":1}"#, #"{"width":0,"height":0,"macOS":26,"seen":1}"#,
    #"{"width":-5,"height":400,"macOS":26,"seen":1}"#, #"{"width":1e9,"height":400,"macOS":26,"seen":1}"#, "[]", "null", "7",
    #"{"width":760,"height":400,"macOS":26.5,"seen":1}"#, #"{"width":760,"height":400,"macOS":26}"#,
  ]) func anEntryThatCannotBeBelievedCostsOnlyItself(entry: String) throws {
    let file = #"{"com.example.bad":\#(entry),"com.example.notes":{"width":709,"height":300,"macOS":26,"seen":1}}"#
    let read = try JSONDecoder().decode(AppSizes.self, from: Data(file.utf8))
    #expect(read.apps.keys.sorted() == ["com.example.notes"])
  }

  // MARK: What a trace says of an app whose first window came while it was recorded

  @Test func aReplayTakesWhatSuchALineSays() {
    var sizes = knowing()
    let notes = AppSizes.Entry(width: 709, height: 0, macOS: 26, seen: morning)
    let taken = sizes.take(notes, for: "com.example.notes")
    #expect(taken)
    #expect(sizes.entry(for: "com.example.notes") == notes)
  }

  @Test func butNotOverWhatTheHeaderSaysNorWhatNoWindowCouldHaveAnswered() {
    var sizes = knowing()
    let before = sizes
    for (width, app) in [(500.0, "com.example.mail"), (-5, "com.example.notes"), (1e9, "com.example.notes"), (500, "")] {
      let taken = sizes.take(AppSizes.Entry(width: width, height: 300, macOS: 26, seen: morning), for: app)
      #expect(!taken, "\(width) for \(app)")
    }
    #expect(sizes == before)
  }

  @Test func aFileWithTooManyIsCutToSize() throws {
    let entries = (0..<(AppSizes.capacity + 50)).map { #""com.example.app\#($0)":{"width":500,"height":300,"macOS":26,"seen":\#($0)}"# }
    let read = try JSONDecoder().decode(AppSizes.self, from: Data("{\(entries.joined(separator: ","))}".utf8))
    #expect(read.apps.count == AppSizes.capacity)
    #expect(read.entry(for: "com.example.app0") == nil)
  }
}
