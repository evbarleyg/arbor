import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// F61, second round, 3: where room is short, whoever has the keyboard is served first. What was lent to the others goes back for it, and
/// if that is not enough they lend. The one exception to "nobody in view pays with their place", so these are about how far it reaches.
extension RoomBeforeTilesTests {
  /// Mail and a chat, floating, started. They do not both fit on 1440 points.
  func mailAndChat() -> (Harness, mail: WindowID, chat: WindowID) {
    let h = Harness()
    let mail = h.system.open(
      app: "Mail", pid: 1001, frame: CGRect(x: 100, y: 100, width: 900, height: 700), minimumSize: CGSize(width: 820, height: 400))
    let chat = h.system.open(
      app: "Chat", pid: 1002, frame: CGRect(x: 300, y: 100, width: 900, height: 700), minimumSize: CGSize(width: 760, height: 500))
    h.start()
    return (h, mail, chat)
  }

  /// The weights of a row or column, as parts of their sum.
  func parts(of row: NodeID, _ h: Harness) -> [Double] {
    let weights = h.workspace.tree.children(of: row).map { h.workspace.tree[$0]!.weight }
    return weights.map { $0 / weights.reduce(0, +) }
  }

  /// Whoever has the keyboard when the view goes out is the one that shows.
  @Test func whoeverHasTheKeyboardWhenTheViewGoesOutIsServedFirst() {
    let (h, mail, chat) = mailAndChat()
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    expectInView(h, chat)
    #expect(isTile(h, mail))
    var rounds: [[WindowID: CGRect?]] = []
    for (typingIn, other) in [(mail, chat), (chat, mail), (mail, chat)] {
      // ⌘Tab to the tile's window: it is framed.
      h.system.userFocus(typingIn)
      h.scheduler.runPending()
      h.run("show-all")
      h.scheduler.runPending()
      expectInView(h, typingIn)
      #expect(isTile(h, other))
      #expect(h.system.focused == typingIn)
      let tree = h.workspace.tree
      h.run("show-all")
      #expect(h.workspace.tree == tree, "and it stays so")
      expectWindowsMatchLayout(h)
      rounds.append([mail: h.frame(mail), chat: h.frame(chat)])
    }
    #expect(rounds[0] == rounds[2], "there and back is nothing")
  }

  /// Where the windows are depends on the gaps as the person left them, on who is there and on who has the keyboard: not on the road.
  @Test func theSameGapsWindowsAndKeyboardGiveTheSameFramesByWhateverRoad() throws {
    typealias Road = (name: String, walk: (Harness, _ mail: WindowID, _ chat: WindowID) -> Void)
    func showAll(_ h: Harness, typingIn window: WindowID) {
      h.system.userFocus(window)
      h.scheduler.runPending()
      h.run("show-all")
      h.scheduler.runPending()
    }
    let larger = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
    let roads: [Road] = [
      ("straight", { _, _, _ in }),
      ("there and back", { h, mail, chat in
        showAll(h, typingIn: mail)
        showAll(h, typingIn: chat)
      }),
      ("the chat in the Dock and back", { h, _, chat in
        h.system.setMinimized(chat, true)
        h.scheduler.runPending()
        h.system.setMinimized(chat, false)
      }),
      ("Mail in the Dock and back", { h, mail, _ in
        h.system.setMinimized(mail, true)
        h.scheduler.runPending()
        h.system.setMinimized(mail, false)
      }),
      ("the chat hidden and back", { h, _, _ in
        h.system.setHidden(pid: 1002, true)
        h.scheduler.runPending()
        h.system.setHidden(pid: 1002, false)
      }),
      ("the chat framed, and out", { h, _, chat in
        h.run("zoom \(chat.rawValue)")
        h.scheduler.runPending()
        h.run("out")
      }),
      ("a larger display and back", { h, _, _ in
        h.system.setDisplays([larger])
        h.scheduler.runPending()
        h.system.setDisplays([FakeWindowSystem.standardDisplay])
      }),
    ]
    var first: Layout?
    for road in roads {
      let (h, mail, chat) = mailAndChat()
      h.system.userFocus(mail)
      h.run("dock \(mail.rawValue) left")
      h.system.userFocus(chat)
      h.run("dock \(chat.rawValue) right")
      road.walk(h, mail, chat)
      h.scheduler.runPending()
      showAll(h, typingIn: mail)
      expectInView(h, mail)
      expectWindowsMatchLayout(h)
      let layout = try #require(h.layout)
      first = first ?? layout
      #expect(layout.windowFrames == first?.windowFrames, "\(road.name)")
      #expect(layout.tiles.map(\.frame) == first?.tiles.map(\.frame), "\(road.name)")
      #expect(layout.desktopFrame == first?.desktopFrame, "\(road.name)")
    }
  }

  /// The window that had the keyboard last is not the window that has it. Mail is a tile, and was typed in before a note was; the note
  /// closes, and nobody has the keyboard. That is no reason for the chat to leave the view.
  @Test func aWindowThatOnlyHadTheKeyboardLastCostsNobodyTheirPlace() throws {
    let (h, mail, chat) = mailAndChat()
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    h.system.userFocus(mail)
    h.scheduler.runPending()
    let note = h.system.open(app: "Notes", pid: 1003, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.scheduler.runPending()
    #expect(h.system.focused == note)
    h.run("show-all")
    h.scheduler.runPending()
    expectInView(h, chat)
    #expect(isTile(h, mail))
    let place = try #require(h.frame(chat))

    h.system.close(note)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused != mail)
    expectInView(h, chat)
    #expect(h.frame(chat) == place)
    #expect(isTile(h, mail))
    expectWindowsMatchLayout(h)
  }

  /// No resizing at every ⌘Tab: between windows that are in view the keyboard goes to and fro and nothing moves. Who has it counts at
  /// the next layout that the person causes.
  @Test func aBareChangeOfTheKeyboardMovesNothing() {
    let (h, mail, chat) = mailAndChat()
    let notes = h.system.open(
      app: "Notes", pid: 1003, frame: CGRect(x: 200, y: 100, width: 500, height: 500), minimumSize: CGSize(width: 300, height: 300))
    h.system.userFocus(notes)
    h.run("dock \(notes.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) right")
    expectInView(h, notes, mail)
    #expect(isTile(h, chat))
    let tree = h.workspace.tree
    h.system.clearFrameLog()
    for window in [notes, mail, notes, mail] {
      h.system.userFocus(window)
      h.scheduler.advance(by: 1)
    }
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.workspace.tree == tree)
    expectWindowsMatchLayout(h)
  }

  /// The person has moved the gap beside the chat, by ten points. That gap is theirs, so Arbor has nothing to take back across it.
  /// The window being typed in shows all the same, and when the chat is typed in again the gap is where the person put it.
  @Test func aGapMovedByHandDoesNotMakeATileOfTheWindowBeingTypedIn() throws {
    let (h, mail, chat) = mailAndChat()
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    let seam = try #require(h.overlays.seams[h.display]?.last)
    h.overlays.dragSeam(seam, by: -10)
    expectInView(h, chat)
    let theirs = try #require(h.frame(chat))
    #expect(theirs.width == 770)

    h.system.userFocus(mail)
    h.scheduler.runPending()
    h.run("show-all")
    h.scheduler.runPending()
    expectInView(h, mail)
    #expect(isTile(h, chat))
    #expect(h.system.focused == mail)
    expectWindowsMatchLayout(h)

    h.system.userFocus(chat)
    h.scheduler.runPending()
    h.run("show-all")
    h.scheduler.runPending()
    expectInView(h, chat)
    #expect(h.frame(chat) == theirs)
    expectWindowsMatchLayout(h)
  }

  /// Mail will not go below 1100 points. Typed in, it leaves the column of the chat and Notes 212, too narrow for anything, so the column is
  /// one tile. Whoever is typed in next in there shows again, and everything is where it was.
  @Test func outOfAColumnThatHasBecomeOneTile() throws {
    let h = Harness()
    let mail = h.system.open(
      app: "Mail", pid: 1001, frame: CGRect(x: 100, y: 100, width: 1200, height: 700), minimumSize: CGSize(width: 1100, height: 400))
    let chat = h.system.open(
      app: "Chat", pid: 1002, frame: CGRect(x: 300, y: 100, width: 600, height: 400), minimumSize: CGSize(width: 400, height: 300))
    let notes = h.system.open(
      app: "Notes", pid: 1003, frame: CGRect(x: 200, y: 100, width: 600, height: 400), minimumSize: CGSize(width: 400, height: 300))
    h.start()
    func showAll(typingIn window: WindowID) {
      h.system.userFocus(window)
      h.scheduler.runPending()
      h.run("show-all")
      h.scheduler.runPending()
      #expect(h.system.focused == window)
      expectInView(h, window)
      expectWindowsMatchLayout(h)
    }
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    h.system.userFocus(notes)
    h.run("dock \(notes.rawValue) beside \(chat.rawValue) bottom")
    showAll(typingIn: chat)
    expectInView(h, chat, notes)
    let before = try #require(h.layout)

    showAll(typingIn: mail)
    #expect(h.layout?.tiles.contains { $0.kind == .group && $0.windows.contains(chat) } == true)

    showAll(typingIn: chat)
    #expect(h.layout?.windowFrames == before.windowFrames)
    #expect(h.layout?.tiles.map(\.frame) == before.tiles.map(\.frame))
  }

  /// Notes has never refused a size, so Arbor does not know what it needs. It lends Mail its place and is a tile too small for any window.
  /// Typed in, it shows again where it was. After a restart too, when Arbor has forgotten what it had learned about anybody.
  @Test(arguments: [false, true]) func aNeighbourThatLentItsPlaceComesBackThoughNothingIsKnownAboutIt(restart: Bool) throws {
    func open(_ h: Harness) -> (mail: WindowID, notes: WindowID) {
      let mail = h.system.open(
        app: "Mail", pid: 1001, frame: CGRect(x: 100, y: 100, width: 1200, height: 700), minimumSize: CGSize(width: 1150, height: 400))
      return (mail, h.system.open(app: "Notes", pid: 1003, frame: CGRect(x: 200, y: 100, width: 500, height: 500)))
    }
    func showAll(_ h: Harness, typingIn window: WindowID) {
      h.system.userFocus(window)
      h.scheduler.runPending()
      h.run("show-all")
      h.scheduler.runPending()
      #expect(h.system.focused == window)
      expectInView(h, window)
      expectWindowsMatchLayout(h)
    }
    var h = Harness()
    let (mail, notes) = open(h)
    h.start()
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(notes)
    h.run("dock \(notes.rawValue) right")
    expectInView(h, notes)
    let place = try #require(h.frame(notes))
    showAll(h, typingIn: mail)
    #expect(isTile(h, notes))
    if restart {
      h.controller.saveNow()
      h = Harness(saved: h.store.saved)
      _ = open(h)
      h.start()
      h.scheduler.runPending()
    }
    showAll(h, typingIn: notes)
    #expect(h.frame(notes) == place)
  }

  /// The person drags the gap until the column of the chat and Notes is one tile. They get the tile they asked for (T20): nothing in it is
  /// fetched out of it, whoever has the keyboard, and the Desktop that they made wider stays as wide.
  @Test func aColumnSqueezedIntoOneTileByHandStaysAsItWasLeft() throws {
    let h = Harness()
    let mail = h.system.open(
      app: "Mail", pid: 1001, frame: CGRect(x: 100, y: 100, width: 1000, height: 700), minimumSize: CGSize(width: 900, height: 400))
    let chat = h.system.open(
      app: "Chat", pid: 1002, frame: CGRect(x: 300, y: 100, width: 600, height: 400), minimumSize: CGSize(width: 300, height: 300))
    let notes = h.system.open(
      app: "Notes", pid: 1003, frame: CGRect(x: 200, y: 100, width: 600, height: 400), minimumSize: CGSize(width: 300, height: 300))
    h.start()
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    h.system.userFocus(notes)
    h.run("dock \(notes.rawValue) beside \(chat.rawValue) bottom")
    expectInView(h, mail, chat, notes)
    let seam = try #require(h.overlays.seams[h.display]?.last { $0.axis == .horizontal })
    h.overlays.dragSeam(seam, by: 250)
    let tile = try #require(h.layout?.tiles.first { $0.kind == .group && $0.windows.contains(chat) })
    let desktop = h.layout?.nodeFrames[h.workspace.tree.desktop]

    h.system.userFocus(chat)
    h.scheduler.runPending()
    h.run("show-all")
    h.scheduler.runPending()
    #expect(h.layout?.tiles.first { $0.node == tile.node }?.frame == tile.frame)
    #expect(h.layout?.nodeFrames[h.workspace.tree.desktop] == desktop)
    expectInView(h, mail)
    expectWindowsMatchLayout(h)
  }

  /// Three windows are enough: Mail on top; below it the Desktop beside a column of Safari and Notes. What Notes borrowed from Safari inside
  /// that column, when it was typed in, decides how far the column can shrink. For Mail's sake it goes back as well.
  @Test func whatWasLentInsideTheGroupBesideItGoesBackIfNothingElseHelps() {
    let h = Harness()
    let mail = h.system.open(
      app: "Mail", pid: 1001, frame: CGRect(x: 100, y: 100, width: 900, height: 650), minimumSize: CGSize(width: 500, height: 600))
    let safari = h.system.open(
      app: "Safari", pid: 1002, frame: CGRect(x: 60, y: 60, width: 900, height: 600), minimumSize: CGSize(width: 800, height: 550))
    let notes = h.system.open(
      app: "Notes", pid: 1003, frame: CGRect(x: 200, y: 100, width: 600, height: 400), minimumSize: CGSize(width: 450, height: 350))
    h.start()
    h.system.userFocus(safari)
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(notes)
    h.run("dock \(notes.rawValue) beside \(safari.rawValue) bottom")
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) top")
    for typingIn in [mail, notes, mail, safari, mail] {
      h.system.userFocus(typingIn)
      h.scheduler.runPending()
      h.run("show-all")
      h.scheduler.runPending()
      #expect(h.system.focused == typingIn)
      expectInView(h, typingIn)
      expectWindowsMatchLayout(h)
    }
  }

  /// A window that is too wide for the display however much goes back. Nothing goes back then.
  @Test func aKeyboardWindowThatFitsNowhereCostsNobodyTheirPlace() {
    let h = Harness()
    let mail = h.system.open(
      app: "Mail", frame: CGRect(x: 100, y: 100, width: 900, height: 700), minimumSize: CGSize(width: 820, height: 400))
    let wide = h.system.open(
      app: "Wide", frame: CGRect(x: 0, y: 100, width: 1600, height: 700), minimumSize: CGSize(width: 1600, height: 500))
    h.start()
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(wide)
    h.run("dock \(wide.rawValue) right")
    h.scheduler.runPending()
    h.run("show-all")
    expectInView(h, mail)
    #expect(isTile(h, wide))
    let tree = h.workspace.tree
    h.run("show-all")
    #expect(h.workspace.tree == tree)
    expectWindowsMatchLayout(h)
  }

  /// The window in the hand has the keyboard, and its slot is one that the drop makes. Notes, the Desktop and Mail, which is 600 points
  /// wide on 136 of the Desktop's; the chat is let go on the lower half of Notes, whose column has to be 760 wide for it.
  @Test func thePreviewOfTheWindowInTheHandIsWhereItLandsThoughANeighbourGivesBackWhatItWasLent() throws {
    let h = Harness()
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 200, y: 100, width: 500, height: 500))
    let mail = h.system.open(
      app: "Mail", frame: CGRect(x: 100, y: 100, width: 700, height: 600), minimumSize: CGSize(width: 600, height: 400))
    let chat = h.system.open(
      app: "Chat", frame: CGRect(x: 300, y: 100, width: 800, height: 520), minimumSize: CGSize(width: 760, height: 400))
    h.start()
    // Once docked and floated again, Arbor knows how narrow the chat will go.
    h.run("dock \(chat.rawValue) left")
    h.run("float \(chat.rawValue)")
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    expectInView(h, notes, mail)
    #expect(h.workspace.tree.hasLoans)

    h.system.userFocus(chat)
    let start = try #require(h.frame(chat))
    let slot = try #require(h.frame(notes))
    h.system.drag(
      chat,
      through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: slot.midX, y: slot.midY), CGPoint(x: slot.midX, y: slot.maxY - 40)])
    expectInView(h, chat, notes)
    #expect(isTile(h, mail))
    let preview = try #require(h.overlays.previewHistory.compactMap { $0 }.last)
    #expect(try #require(h.frame(chat)).approximatelyEquals(preview, tolerance: 1), "\(preview)")
    expectWindowsMatchLayout(h)
  }

  /// Notes holds its place beside Safari's tile, which is the newer of the two. A look into the column of Mail and the chat, where
  /// the two trade places twice, is no reason for that to change: zooming never rearranges what is out of view.
  @Test func aTripIntoAGroupCostsNobodyOutsideItTheirPlace() throws {
    let (h, notes, safari) = makeHarness()
    let mail = h.system.open(
      app: "Mail", frame: CGRect(x: 100, y: 100, width: 700, height: 600), minimumSize: CGSize(width: 300, height: 500))
    let chat = h.system.open(
      app: "Chat", frame: CGRect(x: 300, y: 100, width: 700, height: 600), minimumSize: CGSize(width: 300, height: 450))
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) right")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) beside \(mail.rawValue) bottom")
    h.system.userFocus(notes)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) left")
    expectInView(h, notes, chat)
    #expect(isTile(h, safari) && isTile(h, mail))
    let before = try #require(h.layout)
    let row = parts(of: h.workspace.tree.root, h)

    for typingIn in [mail, chat] {
      // ⌘Tab to the tile's window frames it; one step out is the column.
      h.system.userFocus(typingIn)
      h.scheduler.runPending()
      h.run("out")
      h.scheduler.runPending()
      expectInView(h, typingIn)
      #expect(parts(of: h.workspace.tree.root, h) == row)
    }
    h.run("show-all")
    h.scheduler.runPending()
    expectInView(h, notes, chat)
    #expect(h.layout?.windowFrames == before.windowFrames, "there and back is nothing")
    #expect(h.layout?.tiles.map(\.frame) == before.tiles.map(\.frame))
    expectWindowsMatchLayout(h)
  }

  /// Mail and the chat side by side on 1728 points, both on lent room, the keyboard in `typingIn`.
  func sideBySide(typingIn: (_ mail: WindowID, _ chat: WindowID) -> WindowID) -> (Harness, mail: WindowID, chat: WindowID) {
    let (h, mail, chat) = mailAndChat()
    h.system.setDisplays([
      DisplaySnapshot(
        id: h.display, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), visibleFrame: CGRect(x: 0, y: 33, width: 1728, height: 1084),
        isMain: true)
    ])
    h.system.userFocus(mail)
    h.run("dock \(mail.rawValue) left")
    h.system.userFocus(chat)
    h.run("dock \(chat.rawValue) right")
    h.system.userFocus(typingIn(mail, chat))
    h.scheduler.runPending()
    expectInView(h, mail, chat)
    return (h, mail, chat)
  }

  /// The chat's app makes its window 140 points wider, to the left, and will not go back: a side panel has opened.
  func chatGrows(_ h: Harness, _ chat: WindowID) throws {
    var grown = try #require(h.frame(chat))
    grown.origin.x -= 140
    grown.size.width += 140
    h.system.setMinimumSize(chat, CGSize(width: grown.width, height: 500))
    h.system.userMove(chat, to: grown)
    h.scheduler.advance(by: 1)
  }

  /// The two no longer fit, and something has to give. The window being typed in is the last that may (decided by the product owner).
  @Test func theWindowBeingTypedInStaysInViewWhenItsAppMakesItLarger() throws {
    let (h, mail, chat) = sideBySide { _, chat in chat }
    h.system.clearFrameLog()
    try chatGrows(h, chat)
    expectInView(h, chat)
    #expect(h.frame(chat)?.width == 900)
    #expect(isTile(h, mail))
    #expect(h.system.focused == chat)
    #expect(h.system.frameLog.filter { $0.window == mail }.count == 1, "it leaves the view in one move: \(h.system.frameLog)")
    expectWindowsMatchLayout(h)
    // And nothing more moves by itself.
    let tree = h.workspace.tree
    h.system.clearFrameLog()
    h.scheduler.advance(by: 5)
    #expect(h.workspace.tree == tree && h.system.frameLog.isEmpty)
  }

  /// Found by a hunt. Notes is docked on the right; the person looks at the Desktop, opens Mail and docks it at the top there. Mail goes
  /// away (⌘H, ⌘M) and is fetched again with a click in the Dock. It comes back beside Notes, into a column 65 points too narrow for
  /// it, lay over Notes for a second, and was then swept into a tile with the keyboard in it: what was typed went to a window nobody saw.
  @Test(arguments: ["hidden", "minimized"]) func aWindowFetchedBackIntoAPlaceTooSmallForItIsNotSweptIntoATile(trip: String) {
    let h = Harness()
    let notes = h.system.open(
      app: "Notes", pid: 1001, frame: CGRect(x: 150, y: 80, width: 900, height: 600), minimumSize: CGSize(width: 709, height: 300))
    h.start()
    h.system.userFocus(notes)
    h.run("dock right")
    h.run("desktop")
    h.scheduler.runPending()
    let mail = h.system.open(
      app: "Mail", pid: 1002, frame: CGRect(x: 142, y: 90, width: 1100, height: 700), minimumSize: CGSize(width: 760, height: 400))
    h.system.userFocus(mail)
    h.run("dock top")
    h.scheduler.runPending()
    expectInView(h, mail)

    func away(_ gone: Bool) { trip == "hidden" ? h.system.setHidden(pid: 1002, gone) : h.system.setMinimized(mail, gone) }
    away(true)
    h.scheduler.advance(by: 5)
    away(false)
    h.system.userFocus(mail)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail)
    expectInView(h, mail)
    expectWindowsMatchLayout(h)
  }

  /// Only the window with the keyboard can do that. An app in the background that makes its window larger is the one that pays.
  @Test func anAppInTheBackgroundThatMakesItsWindowLargerCostsNobodyTheirPlace() throws {
    let (h, mail, chat) = sideBySide { mail, _ in mail }
    let place = try #require(h.frame(mail))
    try chatGrows(h, chat)
    expectInView(h, mail)
    #expect(h.frame(mail) == place)
    #expect(isTile(h, chat))
    #expect(h.system.focused == mail)
    expectWindowsMatchLayout(h)
  }
}
