import ArborCore
import Testing

private func window(_ id: UInt32, _ app: String, bundle: String? = nil, title: String = "") -> WindowCandidate {
  WindowCandidate(id: WindowID(id), bundleID: bundle ?? "com.example.\(app.lowercased())", appName: app, title: title)
}

private func ids(_ numbers: UInt32...) -> [WindowID] { numbers.map { WindowID($0) } }

/// What a name means, and which window a slot gets: the one place that decides, for `layout`, presets
/// and every command that names a window by its app.
@Suite struct WindowSlotTests {
  // MARK: Names

  @Test func aNameIsTheBundleIDOrTheAppsName() {
    #expect(AppName.rank("com.apple.Safari", bundleID: "com.apple.Safari", appName: "Safari") == 0)
    #expect(AppName.rank("Safari", bundleID: "com.apple.Safari", appName: "Safari") == 0)
    #expect(AppName.rank("Visual Studio Code", bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code") == 0)
    #expect(AppName.rank("Safari", bundleID: nil, appName: "Safari") == 0)
    #expect(AppName.rank("Mail", bundleID: "com.apple.Safari", appName: "Safari") == nil)
    #expect(AppName.rank("", bundleID: "", appName: "") == nil)
  }

  @Test func caseNeverCounts() {
    #expect(AppName.rank("safari", bundleID: "com.apple.Safari", appName: "Safari") == 0)
    #expect(AppName.rank("COM.APPLE.SAFARI", bundleID: "com.apple.Safari", appName: "Safari") == 0)
    #expect(AppName.rank("CAFÉ", bundleID: nil, appName: "Café") == 0)
    // Composed or decomposed, it is the same name.
    #expect(AppName.rank("Cafe\u{301}", bundleID: nil, appName: "Caf\u{E9}") == 0)
  }

  @Test func theLastPartOfTheBundleIDWillDo() {
    #expect(AppName.rank("Chrome", bundleID: "com.google.Chrome", appName: "Google Chrome") == 1)
    #expect(AppName.rank("vscode", bundleID: "com.microsoft.VSCode", appName: "Code") == 1)
    #expect(AppName.rank("google", bundleID: "com.google.Chrome", appName: "Chrome Browser") == nil)
    #expect(AppName.rank("com", bundleID: "com.google.Chrome", appName: "Chrome Browser") == nil)
  }

  @Test func soWillWholeWordsOfTheName() {
    #expect(AppName.rank("Chrome", bundleID: "x.y", appName: "Google Chrome") == 2)
    #expect(AppName.rank("Studio Code", bundleID: "x.y", appName: "Visual Studio Code") == 2)
    #expect(AppName.rank("visual studio", bundleID: "x.y", appName: "Visual Studio Code") == 2)
    #expect(AppName.rank("Calendar", bundleID: "x.y", appName: "Fantastical - Calendar & Tasks") == 2)
    #expect(AppName.rank("Calendar Tasks", bundleID: "x.y", appName: "Fantastical - Calendar & Tasks") == 2)
    // Parts of words, words out of order and words with others between them are not names.
    #expect(AppName.rank("Chro", bundleID: "x.y", appName: "Google Chrome") == nil)
    #expect(AppName.rank("Code Studio", bundleID: "x.y", appName: "Visual Studio Code") == nil)
    #expect(AppName.rank("Visual Code", bundleID: "x.y", appName: "Visual Studio Code") == nil)
    #expect(AppName.rank("Visual Studio Code Insiders", bundleID: "x.y", appName: "Visual Studio Code") == nil)
    #expect(AppName.rank("&", bundleID: "x.y", appName: "Fantastical - Calendar & Tasks") == nil)
  }

  @Test func onlyTheBestKindOfMatchCounts() {
    let all = [
      window(1, "Visual Studio Code", bundle: "com.microsoft.VSCode"), window(2, "Code", bundle: "org.example.code"),
      window(3, "Code Runner", bundle: "com.example.runner"), window(4, "Code", bundle: "org.example.code"),
    ]
    #expect(AppName.windows(of: "Code", in: all).map(\.id) == ids(2, 4))
    #expect(AppName.windows(of: "Runner", in: all).map(\.id) == ids(3))
    #expect(AppName.windows(of: "Studio", in: all).map(\.id) == ids(1))
    #expect(AppName.windows(of: "Xcode", in: all).isEmpty)
    #expect(AppName.windows(of: "Code", in: []).isEmpty)
  }

  // MARK: Handing windows out

  @Test func slotsTakeTheBestWindowThatIsLeft() {
    let windows = [window(3, "Safari"), window(1, "Mail"), window(2, "Safari"), window(4, "Safari")]
    #expect(WindowSlot.assign([.app("Safari"), .app("Mail"), .app("Safari")], from: windows) == [ids(3), ids(1), ids(2)])
  }

  @Test func noWindowIsHandedOutTwice() {
    let windows = [window(1, "Safari")]
    #expect(WindowSlot.assign([.app("Safari"), .app("safari"), .app("com.example.safari")], from: windows) == [ids(1), [], []])
    #expect(WindowSlot.assign([.window(WindowID(1)), .app("Safari"), .window(WindowID(1))], from: windows) == [ids(1), [], []])
    #expect(WindowSlot.assign([.app("Safari", takesAll: true), .app("Safari", takesAll: true)], from: windows) == [ids(1), []])
    // Nor when the caller lists it twice.
    #expect(WindowSlot.assign([.app("Safari"), .app("Safari")], from: windows + windows) == [ids(1), []])
  }

  @Test func aStarTakesWhatTheOthersLeave() {
    let windows = [window(1, "Safari"), window(2, "Safari"), window(3, "Mail"), window(4, "Safari"), window(5, "Safari")]
    // Although it is written first.
    #expect(WindowSlot.assign([.app("Safari", takesAll: true), .app("Safari"), .app("Safari")], from: windows) == [ids(4, 5), ids(1), ids(2)])
    #expect(WindowSlot.assign([.app("Safari", takesAll: true)], from: windows) == [ids(1, 2, 4, 5)])
    #expect(WindowSlot.assign([.app("Notes", takesAll: true)], from: windows) == [[]])
  }

  @Test func aWindowNamedByNumberIsNotLeftForItsApp() {
    let windows = [window(1, "Safari"), window(2, "Safari")]
    #expect(WindowSlot.assign([.app("Safari"), .window(WindowID(1))], from: windows) == [ids(2), ids(1)])
    #expect(WindowSlot.assign([.window(WindowID(9))], from: windows) == [[]])
  }

  @Test func aTitleGetsFirstPick() {
    let windows = [
      window(1, "Safari", title: "News"), window(2, "Safari", title: "Inbox (3) - Fastmail"), window(3, "Safari", title: "Docs"),
    ]
    #expect(WindowSlot.assign([.app("Safari"), .app("Safari", title: "inbox")], from: windows) == [ids(1), ids(2)])
    #expect(WindowSlot.assign([.app("Safari", title: "Docs"), .app("Safari", title: "News")], from: windows) == [ids(3), ids(1)])
    // Two slots after the same title: the first written gets it.
    #expect(WindowSlot.assign([.app("Safari", title: "Docs"), .app("Safari", title: "Docs")], from: windows) == [ids(3), ids(1)])
  }

  @Test func aTitleNobodyHasIsOnlyALostPreference() {
    let windows = [window(1, "Safari", title: "News"), window(2, "Safari", title: "Docs")]
    #expect(WindowSlot.assign([.app("Safari", title: "Inbox")], from: windows) == [ids(1)])
    // It waits until those whose title was found have chosen, then chooses in its turn.
    #expect(WindowSlot.assign([.app("Safari", title: "Inbox"), .app("Safari", title: "News")], from: windows) == [ids(2), ids(1)])
    #expect(WindowSlot.assign([.app("Safari", title: "Inbox"), .app("Safari")], from: windows) == [ids(1), ids(2)])
    // The title of another app's window does not help.
    #expect(WindowSlot.assign([.app("Mail", title: "News")], from: windows) == [[]])
  }

  @Test func aStarWithATitleTakesOnlyThoseThatHaveIt() {
    let windows = [
      window(1, "Safari", title: "GitHub: pulls"), window(2, "Safari", title: "News"), window(3, "Safari", title: "github: issues"),
    ]
    #expect(WindowSlot.assign([.app("Safari", title: "GitHub", takesAll: true), .app("Safari", takesAll: true)], from: windows) == [ids(1, 3), ids(2)])
    #expect(WindowSlot.assign([.app("Safari", title: "Jira", takesAll: true)], from: windows) == [[]])
  }

  @Test func whatANameMeansDoesNotChangeAsWindowsAreTaken() {
    // The second `Code` does not spill over to Visual Studio Code when Code has run out of windows.
    let windows = [window(1, "Code"), window(2, "Visual Studio Code")]
    #expect(WindowSlot.assign([.app("Code"), .app("Code")], from: windows) == [ids(1), []])
    #expect(WindowSlot.assign([.window(WindowID(1)), .app("Code")], from: windows) == [ids(1), []])
  }

  // MARK: Windows that are already in place

  @Test func aWindowAlreadyInItsPlaceStaysThere() {
    // 1 was used last, but 2 is where the first slot would put a window.
    let windows = [window(1, "Safari"), window(2, "Safari"), window(3, "Safari")]
    let slots: [WindowSlot] = [.app("Safari"), .app("Safari")]
    #expect(WindowSlot.assign(slots, from: windows) == [ids(1), ids(2)])
    #expect(WindowSlot.assign(slots, from: windows, preferring: [ids(2), ids(1)]) == [ids(2), ids(1)])
    #expect(WindowSlot.assign(slots, from: windows, preferring: [ids(3), []]) == [ids(3), ids(1)])
  }

  @Test func itIsNotTakenByAnEarlierSlotThatHasToChoose() {
    // The first slot's window has closed. It does not take the second's, though that was used last.
    let windows = [window(2, "Safari"), window(3, "Safari")]
    #expect(WindowSlot.assign([.app("Safari"), .app("Safari")], from: windows, preferring: [ids(1), ids(2)]) == [ids(3), ids(2)])
  }

  @Test func whatIsInPlaceButDoesNotFitIsIgnored() {
    let windows = [window(1, "Safari"), window(2, "Mail")]
    #expect(WindowSlot.assign([.app("Safari")], from: windows, preferring: [ids(2)]) == [ids(1)])
    #expect(WindowSlot.assign([.app("Safari")], from: windows, preferring: [ids(9)]) == [ids(1)])
    #expect(WindowSlot.assign([.app("Safari")], from: windows, preferring: [[], ids(1), ids(2)]) == [ids(1)])
    #expect(WindowSlot.assign([.window(WindowID(1))], from: windows, preferring: [ids(2)]) == [ids(1)])
  }

  @Test func aTitleThatIsFoundStillComesFirst() {
    let windows = [window(1, "Safari", title: "News"), window(2, "Safari", title: "Inbox")]
    #expect(WindowSlot.assign([.app("Safari", title: "Inbox")], from: windows, preferring: [ids(1)]) == [ids(2)])
    // Among those that have it, the one in place.
    let two = [window(1, "Safari", title: "Inbox A"), window(2, "Safari", title: "Inbox B")]
    #expect(WindowSlot.assign([.app("Safari", title: "Inbox")], from: two, preferring: [ids(2)]) == [ids(2)])
  }

  @Test func tabsKeepTheirOrder() {
    let windows = [window(3, "Safari"), window(1, "Safari"), window(2, "Safari"), window(4, "Safari")]
    #expect(WindowSlot.assign([.app("Safari", takesAll: true)], from: windows, preferring: [ids(1, 2, 3)]) == [ids(1, 2, 3, 4)])
  }

  @Test func nothingToMatchIsFine() {
    #expect(WindowSlot.assign([], from: []).isEmpty)
    #expect(WindowSlot.assign([], from: [window(1, "A")]).isEmpty)
    #expect(WindowSlot.assign([.app("A"), .window(WindowID(1)), .app("A", takesAll: true)], from: []) == [[], [], []])
  }

  @Test func anEmptyTitleIsNoTitle() {
    #expect(WindowSlot.app("A", title: "") == WindowSlot.app("A"))
    #expect(WindowSlot.app("A", title: "").matchesTitle("anything"))
  }

  @Test func aNewcomerIsAcceptedByItsAppsSlots() {
    #expect(WindowSlot.app("Chrome").accepts(window(1, "Google Chrome", bundle: "com.google.Chrome")))
    #expect(WindowSlot.app("com.google.chrome").accepts(window(1, "Google Chrome", bundle: "com.google.Chrome")))
    #expect(!WindowSlot.app("Safari").accepts(window(1, "Google Chrome", bundle: "com.google.Chrome")))
    #expect(WindowSlot.window(WindowID(1)).accepts(window(1, "A")))
    #expect(!WindowSlot.window(WindowID(2)).accepts(window(1, "A")))
  }

  @Test func everyWindowGoesToAtMostOneSlotWhateverIsAsked() {
    var random = NotationRandom(seed: 11)
    let apps = ["Safari", "Mail", "Code", "Visual Studio Code", "Google Chrome", "Chrome"]
    let titles = ["Inbox", "News", "Docs", ""]
    for _ in 0..<2000 {
      let windows = (0..<Int.random(in: 0...8, using: &random)).map { _ in
        window(UInt32.random(in: 1...10, using: &random), apps.randomElement(using: &random)!, title: titles.randomElement(using: &random)!)
      }
      let slots = (0..<Int.random(in: 0...8, using: &random)).map { _ -> WindowSlot in
        if Int.random(in: 0..<5, using: &random) == 0 { return .window(WindowID(UInt32.random(in: 1...10, using: &random))) }
        return .app(
          (apps + ["Studio", "Nothing"]).randomElement(using: &random)!, title: Bool.random(using: &random) ? titles.randomElement(using: &random) : nil,
          takesAll: Int.random(in: 0..<4, using: &random) == 0)
      }
      let inPlace = Bool.random(using: &random) ? [] : slots.map { _ in (0..<Int.random(in: 0...2, using: &random)).map { _ in WindowID(UInt32.random(in: 1...10, using: &random)) } }
      let result = WindowSlot.assign(slots, from: windows, preferring: inPlace)
      // Applied again with that as what is in place, nothing changes.
      var listed = Set<WindowID>()
      let once = windows.filter { listed.insert($0.id).inserted }
      #expect(WindowSlot.assign(slots, from: once.shuffled(using: &random), preferring: result) == result, "\(slots) \(once)")
      #expect(result.count == slots.count)
      let all = result.flatMap { $0 }
      #expect(Set(all).count == all.count)
      #expect(Set(all).isSubset(of: Set(windows.map(\.id))))
      for (slot, got) in zip(slots, result) where !slot.takesAll { #expect(got.count <= 1) }
      for (slot, got) in zip(slots, result) {
        for id in got { #expect(slot.accepts(windows.first { $0.id == id }!)) }
      }
    }
  }

  // MARK: How closely a title matches

  @Test func aTitleMatchesAsAWholeAtItsBeginningOrSomewhere() {
    let slot = WindowSlot.app("Mail", title: "Inbox")
    #expect(slot.match(of: "Inbox") == .whole && slot.match(of: "INBOX") == .whole)
    #expect(slot.match(of: "Inbox (2)") == .beginning && slot.match(of: "inbox — Mail") == .beginning)
    #expect(slot.match(of: "Re: Inbox") == .somewhere && slot.match(of: "My inbox, again") == .somewhere)
    #expect(slot.match(of: "Outbox") == nil && slot.match(of: "") == nil)
    #expect(WindowSlot.app("Mail").match(of: "Inbox") == nil && WindowSlot.app("Mail").matchesTitle("Inbox"), "without a text every title will do")
    // The first place it is found at decides: here that is the beginning.
    #expect(WindowSlot.app("Mail", title: "a").match(of: "aa") == .beginning)
  }

  /// Offered in every order, since the order is who was used last.
  @Test func theClosestTitleWinsWhoeverWasUsedLast() {
    let titles = ["Inbox", "Inbox (2)", "Re: Inbox"]
    let slots = titles.map { WindowSlot.app("Mail", title: $0) }
    for order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]] {
      let candidates = order.map { WindowCandidate(id: WindowID(UInt32($0 + 1)), bundleID: nil, appName: "Mail", title: titles[$0]) }
      #expect(WindowSlot.assign(slots, from: candidates) == [[WindowID(1)], [WindowID(2)], [WindowID(3)]], "\(order)")
      #expect(WindowSlot.assign(slots.reversed(), from: candidates) == [[WindowID(3)], [WindowID(2)], [WindowID(1)]], "\(order), written the other way round")
    }
  }

  /// A vague slot that is written first does not take the window a later slot names exactly.
  @Test func whatIsNamedExactlyIsNotTakenByAVagueSlot() {
    let candidates = ["1 x", "2 x"].enumerated().map { WindowCandidate(id: WindowID(UInt32($0.offset + 1)), bundleID: nil, appName: "A", title: $0.element) }
    #expect(WindowSlot.assign([.app("A", title: "x"), .app("A", title: "1 x")], from: candidates) == [[WindowID(2)], [WindowID(1)]])
    #expect(WindowSlot.assign([.app("A", title: "x"), .app("A", title: "2")], from: candidates) == [[WindowID(1)], [WindowID(2)]])
    // A title is still a preference: a slot whose text is found nowhere takes another window of the app.
    #expect(WindowSlot.assign([.app("A", title: "nowhere"), .app("A", title: "1 x")], from: candidates) == [[WindowID(2)], [WindowID(1)]])
  }
}
