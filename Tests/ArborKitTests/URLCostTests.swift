import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// A link may arrange, and may not take away what a person made (Controller+URLCost.swift).
@Suite @MainActor struct URLCostTests {
  func harness(_ apps: String..., displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Settings()) -> Harness {
    let h = Harness(displays: displays, settings: settings)
    for app in apps { h.system.open(app: app) }
    h.start()
    return h
  }

  /// Safari beside Mail over Notes; Mail and Notes are view 1 and are called Post.
  func desk(settings: Settings = Settings()) -> Harness {
    let h = harness("Safari", "Mail", "Notes", settings: settings)
    for line in ["layout Safari | (Mail / Notes)", "zoom 102", "out", "save-view 1", "name Post", "home"] { #expect(h.run(line).ok, "\(line)") }
    return h
  }

  func made(_ h: Harness) -> (views: Int, names: Int) {
    h.controller.workspaces.values.reduce((0, 0)) { ($0.0 + $1.savedViews.count, $0.1 + $1.names.count) }
  }

  func refusal(_ h: Harness, _ url: String) -> String? {
    if case .failure(let error) = h.controller.admit(url: url) { return error.description }
    return nil
  }

  static let wayOut = "use a shortcut, the menu or arborctl, or set allowAllURLCommands to true in settings.json to allow it"

  @Test func arrangeIsRefusedWhereItWouldCostASavedViewOrAName() {
    let h = desk()
    let before = h.controller.workspaces
    #expect(refusal(h, "arbor://arrange") == "`arrange` would cost 1 saved view and 1 name, which a URL may not; \(Self.wayOut)")
    #expect(refusal(h, "arbor://arrange/all") == "`arrange` would cost 1 saved view and 1 name, which a URL may not; \(Self.wayOut)")
    #expect(h.controller.workspaces == before, "asking changes nothing")
    // Only one of the two.
    #expect(h.run("unname Post").ok)
    #expect(refusal(h, "arbor://arrange") == "`arrange` would cost 1 saved view, which a URL may not; \(Self.wayOut)")
    let named = harness("Safari", "Mail")
    for line in ["arrange", "zoom 101", "name Reading", "zoom 102", "name Post", "home"] { #expect(named.run(line).ok, "\(line)") }
    #expect(refusal(named, "arbor://arrange") == "`arrange` would cost 2 names, which a URL may not; \(Self.wayOut)")
  }

  @Test func whereNothingIsLostTheyStayAllowed() {
    let h = harness("Safari", "Mail", "Notes")
    for url in ["arbor://arrange", "arbor://arrange/all", "arbor://layout/Safari%20%7C%20Mail", "arbor://layout/Notes"] {
      guard case .success(let command) = h.controller.admit(url: url) else { Issue.record("\(url) was refused"); continue }
      #expect(h.controller.perform(command, from: .url).ok, "\(url)")
    }
  }

  @Test func aLineIsRefusedWhereItTakesApartASpaceThatIsSavedOrNamed() {
    let h = desk()
    let before = h.controller.workspaces
    #expect(
      refusal(h, "arbor://layout/(Safari%20%2F%20Mail)%20%7C%20Notes") == "`layout` would cost 1 saved view and 1 name, which a URL may not; \(Self.wayOut)")
    #expect(refusal(h, "arbor://layout/Safari")?.hasPrefix("`layout` would cost 1 saved view and 1 name") == true, "all but one window float")
    #expect(h.controller.workspaces == before, "asking changes nothing")
  }

  /// Saved views and names follow the spaces that still hold the same windows, so such a line costs nothing.
  @Test func aLineThatKeepsTheSavedSpaceIsAllowed() {
    let h = desk()
    for url in ["arbor://layout/Safari:2%20%7C%20(Mail%20%2F%20Notes)", "arbor://layout/(Notes%20%2F%20Mail)%20%7C%20Safari"] {
      guard case .success(let command) = h.controller.admit(url: url) else { Issue.record("\(url) was refused: \(refusal(h, url) ?? "")"); continue }
      #expect(h.controller.perform(command, from: .url).message == "arranged 3 windows", "\(url)")
      #expect(made(h) == (1, 1))
    }
  }

  /// A line that finds none of its windows changes nothing, and says so itself.
  @Test func aLineThatWouldChangeNothingIsNotRefusedForItsCost() {
    let h = desk()
    guard case .success(let command) = h.controller.admit(url: "arbor://layout/Nobody") else { return #expect(Bool(false), "refused") }
    #expect(h.controller.perform(command, from: .url).message == "no window of Nobody; nothing changed")
    #expect(made(h) == (1, 1))
  }

  @Test func theSettingLiftsIt() {
    var settings = Settings()
    settings.allowAllURLCommands = true
    let h = desk(settings: settings)
    guard case .success(let command) = h.controller.admit(url: "arbor://arrange") else { return #expect(Bool(false), "refused") }
    #expect(h.controller.perform(command, from: .url).message == "arranged 3 windows; 1 saved view is gone; 1 name is gone")
  }

  /// It is about links. Whoever sits at the Mac may do as they like, and is told what went.
  @Test func shortcutsTheMenuAndScriptsAreNotConcerned() {
    for source in [CommandSource.shortcut, .menu, .script] {
      #expect(desk().controller.perform(.arrange, from: source).message == "arranged 3 windows; 1 saved view is gone; 1 name is gone", "\(source)")
    }
    #expect(desk().run("layout Safari").ok)
  }

  /// `arrange` acts on one display, `arrange all` on each, and a line can fetch a window from another.
  @Test func whatCountsIsWhatTheCommandWouldTouch() {
    let h = harness("Safari", "Mail", displays: [FakeWindowSystem.standardDisplay, side])
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    #expect(h.run("layout @1 Safari | Mail").ok && h.run("layout @2 Notes").ok)
    // Commands that name no display go where the person is.
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.system.userFocus(notes)
    #expect(h.run("zoom \(notes.rawValue)").ok && h.run("name Scraps").ok && h.run("home").ok)
    #expect(h.controller.workspaces[side.id]?.names.keys.sorted() == ["Scraps"] && made(h) == (0, 1))
    #expect(refusal(h, "arbor://arrange")?.hasPrefix("`arrange` would cost 1 name") == true, "the person is at that display")
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.system.userFocus(WindowID(101))
    #expect(refusal(h, "arbor://arrange") == nil, "and now at the other, which has nothing to lose")
    #expect(refusal(h, "arbor://layout/@1%20Mail%20%7C%20Safari") == nil, "the other display is left alone")
    #expect(refusal(h, "arbor://arrange/all")?.hasPrefix("`arrange` would cost 1 name") == true)
    #expect(refusal(h, "arbor://layout/@1%20Safari%20%7C%20Notes")?.hasPrefix("`layout` would cost 1 name") == true, "Notes leaves the space that is called Scraps")
    #expect(made(h) == (0, 1), "asking changes nothing")
  }

  /// The reason holds numbers only, and the log gets no part of a line (titles) whatever the reason.
  @Test func theReasonHoldsNoWordOfTheLineOrOfTheNames() {
    let h = desk()
    let reason = refusal(h, "arbor://layout/Safari~Secret") ?? ""
    #expect(reason.hasPrefix("`layout` would cost") && !reason.contains("Secret") && !reason.contains("Post"))
  }

  /// What is foretold is what happens: the dry run does to copies what the commands do, and must go on doing so.
  /// (About five commands a walk; of the first 60 walks' 309, 136 cost something and 173 nothing, on one display and on two.)
  @Test(arguments: 0..<200) func whatIsForetoldIsWhatHappens(seed: Int) {
    var random = ChaosRandom(seed: UInt64(seed) &* 7919 &+ 1)
    let apps = ["A", "B", "C", "D", "E"]
    let two = random.chance(40)
    let h = Harness(displays: two ? [FakeWindowSystem.standardDisplay, side] : [FakeWindowSystem.standardDisplay])
    for app in apps {
      if two, random.chance(40) { h.system.open(app: app, frame: CGRect(x: 1600, y: 100, width: 500, height: 400)) } else { h.system.open(app: app) }
    }
    h.start()
    func line(_ r: inout ChaosRandom) -> String {
      var names = apps
      for i in names.indices.reversed() { names.swapAt(i, r.int(0...i)) }
      names = Array(names.prefix(r.int(1...apps.count)))
      var parts: [String] = []
      while !names.isEmpty {
        let take = min(r.int(1...3), names.count)
        let group = Array(names.prefix(take))
        names.removeFirst(take)
        parts.append(take == 1 ? group[0] : r.chance(25) ? "[\(group.joined(separator: " "))]" : "(\(group.joined(separator: " / ")))")
      }
      return (two && r.chance(50) ? "@\(r.int(1...2)) " : "") + parts.joined(separator: " | ")
    }
    for step in 0..<14 {
      // Something to lose: an arrangement, and views and names of whatever is framed.
      switch random.int(0...5) {
      case 0: h.run("layout \(line(&random))")
      case 1: h.run("zoom \(100 + random.int(1...apps.count))")
      case 2: h.run("out")
      case 3: h.run("save-view \(random.int(1...4))")
      case 4: h.run("name N\(random.int(1...4))")
      default: h.system.userFocus(WindowID(UInt32(100 + random.int(1...apps.count))))
      }
      guard step > 3, random.chance(50) else { continue }
      let text = random.pick(["arrange", "arrange all", "layout \(line(&random))", "layout \(line(&random))"])!
      guard let command = try? Command.parse(text) else { Issue.record("\(text) does not parse"); continue }
      let url = "arbor://" + text.split(separator: " ", maxSplits: 1).map { part in
        part.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
      }.joined(separator: "/")
      let state = h.controller.workspaces
      let refused = refusal(h, url)
      #expect(h.controller.workspaces == state, "asking changes nothing: \(text)")
      let before = made(h)
      h.controller.perform(command, from: .url)
      let lost = (views: before.views - made(h).views, names: before.names - made(h).names)
      if lost == (0, 0) {
        #expect(refused == nil, "seed \(seed), \(text): nothing went, and it was refused: \(refused ?? "")")
      } else {
        let words = [lost.views > 0 ? "\(lost.views) saved view\(lost.views == 1 ? "" : "s")" : nil, lost.names > 0 ? "\(lost.names) name\(lost.names == 1 ? "" : "s")" : nil]
          .compactMap { $0 }.joined(separator: " and ")
        #expect(refused?.contains(" would cost \(words), which") == true, "seed \(seed), \(text): \(words) went; the link was told: \(refused ?? "nothing")")
      }
    }
  }
}
