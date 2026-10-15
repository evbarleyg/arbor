import ArborCore
import CoreGraphics
import Foundation
import Testing

@testable import ArborKit
@testable import ArborTesting

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

private func transition(_ items: [Transition.Item], duration: Double = 0.4) -> Transition {
  Transition(display: DisplayID("main"), frame: screen, duration: duration, items: items)
}

private func near(_ a: CGRect, _ b: CGRect, within tolerance: CGFloat = 0.01) -> Bool {
  a.approximatelyEquals(b, tolerance: tolerance)
}

/// The stage without a screen keeps to the rules of `Stage` (ArborKit/UI/Stage.swift).
@Suite struct StagePlaybackTests {
  private let a = WindowID(101)
  private let b = WindowID(102)
  private let left = CGRect(x: 0, y: 0, width: 400, height: 300)
  private let right = CGRect(x: 1000, y: 100, width: 200, height: 600)

  @Test func aStandInTravelsFromWhereTheWindowWasToWhereItWent() throws {
    var stage = StagePlayback()
    #expect(stage.picture(at: 0) == nil)
    stage.play(transition([.init(window: a, from: left, to: right)]), at: 10, surface: nil)

    #expect(near(try #require(stage.picture(at: 10)).standIns[0].frame, left))
    let share = CGFloat(TimingCurve.motion.progress(at: 0.25))
    let quarter = try #require(stage.picture(at: 10.1)).standIns[0].frame
    #expect(abs(quarter.minX - 1000 * share) < 0.01)
    #expect(abs(quarter.width - (400 - 200 * share)) < 0.01)
    #expect(near(try #require(stage.picture(at: 10.4)).standIns[0].frame, right))
  }

  @Test func theStageLiftsWhenTheTimeIsUpAndIsGoneAMomentLater() throws {
    var stage = StagePlayback()
    stage.play(transition([.init(window: a, from: left, to: right)]), at: 0, surface: nil)
    #expect(try #require(stage.picture(at: 0.39)).opacity == 1)
    let lifting = try #require(stage.picture(at: 0.4 + StagePlayback.liftDuration / 2)).opacity
    #expect(lifting > 0 && lifting < 1)
    #expect(stage.picture(at: 0.4 + StagePlayback.liftDuration) == nil)
    #expect(!stage.isUp(at: 0.4 + StagePlayback.liftDuration))
  }

  @Test func aSecondMotionCarriesOnFromWhereThingsAre() throws {
    var stage = StagePlayback()
    stage.play(transition([.init(window: a, from: left, to: right)]), at: 0, surface: nil)
    let midway = try #require(stage.picture(at: 0.1)).standIns[0].frame
    // Its `from` is where the real window was, which by now is where the first motion was taking it.
    stage.play(transition([.init(window: a, from: right, to: left)]), at: 0.1, surface: nil)
    #expect(near(try #require(stage.picture(at: 0.1)).standIns[0].frame, midway))
    #expect(near(try #require(stage.picture(at: 0.5)).standIns[0].frame, left))
    #expect(try #require(stage.picture(at: 0.45)).opacity == 1)
  }

  @Test func aWindowThatIsNoLongerPartOfItFadesAwayWhereItIs() throws {
    var stage = StagePlayback()
    stage.play(transition([.init(window: a, from: left, to: right), .init(window: b, from: right, to: left)]), at: 0, surface: nil)
    let midway = try #require(stage.picture(at: 0.1)).standIns.first { $0.window == b }?.frame
    stage.play(transition([.init(window: a, from: right, to: right)]), at: 0.1, surface: nil)
    let picture = try #require(stage.picture(at: 0.3))
    let later = try #require(picture.standIns.first { $0.window == b })
    #expect(midway.map { near(later.frame, $0) } == true)
    #expect(later.opacity < 0.2)
  }

  @Test func withoutAPictureAWindowShowsItsCoverWhateverLookIsAskedFor() throws {
    var stage = StagePlayback()
    stage.play(transition([.init(window: a, from: left, to: right, fromLook: .picture, toLook: .picture)]), at: 0, surface: nil)
    for time in [0, 0.2, 0.4] {
      let standIn = try #require(stage.picture(at: time)).standIns[0]
      #expect(standIn.cover == 1)
      #expect(standIn.picture == 0)
    }
  }

  @Test func withAPictureTheLooksCrossFade() throws {
    var stage = StagePlayback()
    stage.play(
      transition([.init(window: a, from: left, to: right, fromLook: .cover, toLook: .picture)]), at: 0, surface: nil,
      hasPicture: { _ in true })
    #expect(try #require(stage.picture(at: 0)).standIns[0].cover == 1)
    let midway = try #require(stage.picture(at: 0.05)).standIns[0]
    #expect(abs(midway.cover + midway.picture - 1) < 1e-9)
    #expect(midway.picture > 0 && midway.picture < 1)
    #expect(try #require(stage.picture(at: 0.4)).standIns[0].picture == 1)
  }

  @Test func standInsAreStackedAsTheTransitionListsThem() throws {
    var stage = StagePlayback()
    stage.play(transition([.init(window: b, from: left, to: right), .init(window: a, from: right, to: left)]), at: 0, surface: nil)
    #expect(try #require(stage.picture(at: 0.1)).standIns.map(\.window) == [b, a])
  }

  @Test func theSurfaceFadesIntoTheShapeTheMotionEndsIn() throws {
    let before = BackdropModel(frame: screen, rects: [left], growth: 6, dim: 0.25, blur: 0)
    let after = BackdropModel(frame: screen, rects: [right], growth: 6, dim: 0.25, blur: 0)
    var stage = StagePlayback()
    stage.play(transition([.init(window: a, from: left, to: right)]), at: 0, surface: before)
    #expect(try #require(stage.picture(at: 0)).surfaces == [.init(model: before, opacity: 1)])
    stage.show(surface: after, at: 0)
    let midway = try #require(stage.picture(at: 0.2)).surfaces
    #expect(midway.map(\.model) == [before, after])
    #expect(abs(midway[0].opacity + midway[1].opacity - 1) < 1e-9)
    #expect(try #require(stage.picture(at: 0.4)).surfaces == [.init(model: after, opacity: 1)])
  }

  @Test func droppedItIsDownAtOnce() {
    var stage = StagePlayback()
    stage.play(transition([.init(window: a, from: left, to: right)]), at: 0, surface: nil)
    stage.drop()
    #expect(stage.picture(at: 0.1) == nil)
  }
}

/// The panels without a screen keep to the rules of `AppKitOverlays` and its panels.
@MainActor
@Suite struct OverlayPlaybackTests {
  private let overlays = FakeOverlays()
  private let display = FakeWindowSystem.standardDisplay.id

  private final class Clock { var now = 0.0 }

  @Test func thePreviewFadesInGlidesToTheNextTargetAndFadesOut() throws {
    let clock = Clock()
    let playback = OverlayPlayback(overlays) { clock.now }
    let (first, second) = (CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 200, y: 0, width: 300, height: 100))
    #expect(playback.dropPreview == nil)

    overlays.showDropPreview(first)
    clock.now = OverlayPlayback.previewMotion / 2
    let arriving = try #require(playback.dropPreview)
    #expect(arriving.model == first)
    #expect(arriving.opacity > 0 && arriving.opacity < 1)

    clock.now = 1
    overlays.showDropPreview(second)
    clock.now = 1 + OverlayPlayback.previewMotion / 2
    let gliding = try #require(playback.dropPreview)
    #expect(gliding.opacity == 1)
    #expect(gliding.model.minX > 0 && gliding.model.minX < 200)
    clock.now = 1 + OverlayPlayback.previewMotion
    #expect(try #require(playback.dropPreview).model == second)

    clock.now = 2
    overlays.showDropPreview(nil)
    clock.now = 2 + OverlayPlayback.previewMotion / 2
    #expect(try #require(playback.dropPreview).opacity < 1)
    clock.now = 2 + OverlayPlayback.previewMotion
    #expect(playback.dropPreview == nil)

    // Shown again somewhere else, it appears there: it does not glide in from where it last was.
    overlays.showDropPreview(first)
    clock.now += 0.01
    #expect(try #require(playback.dropPreview).model == first)
  }

  @Test func theHeadsUpLineKeepsItsWordsWhileItFadesOut() throws {
    let clock = Clock()
    let playback = OverlayPlayback(overlays) { clock.now }
    let line = HeadsUpModel(kind: .hint, text: "Docked")
    overlays.showHeadsUp(line, on: display)
    clock.now = OverlayPlayback.passingFadeIn
    #expect(playback.headsUpLine == .init(model: line, opacity: 1))
    clock.now = 2
    overlays.showHeadsUp(nil, on: display)
    clock.now = 2 + OverlayPlayback.passingFadeOut / 2
    let leaving = try #require(playback.headsUpLine)
    #expect(leaving.model == line)
    #expect(leaving.opacity > 0 && leaving.opacity < 1)
    clock.now = 2 + OverlayPlayback.passingFadeOut
    #expect(playback.headsUpLine == nil)
  }

  @Test func oneShapeOfTheSurfaceFadesIntoTheNextButNotDuringADrag() {
    let clock = Clock()
    let playback = OverlayPlayback(overlays) { clock.now }
    func scene(_ x: CGFloat) -> OverlayScene {
      var scene = OverlayScene()
      scene.backdrop = BackdropModel(
        frame: screen, rects: [CGRect(x: x, y: 0, width: 100, height: 100)], growth: 6, dim: 0.25, blur: 0)
      return scene
    }
    clock.now = 1
    overlays.update(display: display, scene: scene(0))
    clock.now = 1 + OverlayPlayback.backdropFade / 2
    #expect(playback.backdrops(on: display).count == 1)
    #expect(playback.backdrops(on: display)[0].opacity < 1)

    clock.now = 2
    overlays.update(display: display, scene: scene(10))
    clock.now = 2.05
    #expect(playback.backdrops(on: display).count == 2)
    // The next change comes before the fade is over, as every step of a drag does: no smear behind the pointer.
    overlays.update(display: display, scene: scene(20))
    #expect(playback.backdrops(on: display) == [.init(model: scene(20).backdrop!, opacity: 1)])
  }

  @Test func aTileFadesInOnceHoweverOftenTheSceneIsShownAgain() {
    let clock = Clock()
    let playback = OverlayPlayback(overlays) { clock.now }
    var scene = OverlayScene(tiles: [
      TileModel(display: display, node: NodeID(3), kind: .window, frame: CGRect(x: 0, y: 0, width: 100, height: 100), items: [])
    ])
    scene.tileFade = 0.2
    overlays.update(display: display, scene: scene)
    for step in 1...3 {
      clock.now = Double(step) * 0.05
      // Something else about the scene changes, as when a floating window moves.
      scene.peekOutline = CGRect(x: CGFloat(step), y: 0, width: 10, height: 10)
      overlays.update(display: display, scene: scene)
    }
    clock.now = 0.2
    #expect(playback.tiles(on: display).map(\.opacity) == [1])

    // Gone, it fades out; asked for again meanwhile, it comes back from however faint it is.
    var empty = OverlayScene()
    empty.tileFade = 0.2
    overlays.update(display: display, scene: empty)
    clock.now = 0.3
    let leaving = playback.tiles(on: display).first?.opacity ?? 0
    #expect(leaving > 0 && leaving < 1)
    overlays.update(display: display, scene: scene)
    #expect(playback.tiles(on: display).map(\.opacity) == [leaving])
    clock.now = 0.5
    #expect(playback.tiles(on: display).map(\.opacity) == [1])
  }

  @Test func theRingFlashesWhenArborMovedTheKeyboard() {
    let clock = Clock()
    let playback = OverlayPlayback(overlays) { clock.now }
    func scene(pulse: Int) -> OverlayScene {
      var scene = OverlayScene()
      let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
      scene.focusRing = FocusRingModel(
        window: WindowID(101), frame: frame, outerFrame: frame.insetBy(dx: -3, dy: -3), width: 3, radius: 0, colour: .accent,
        pulse: pulse)
      return scene
    }
    overlays.update(display: display, scene: scene(pulse: 0))
    #expect(playback.flash == 0)
    clock.now = 1
    overlays.update(display: display, scene: scene(pulse: 1))
    #expect(playback.flash == 1)
    clock.now = 1 + FocusRingModel.pulseDuration / 2
    #expect(playback.flash > 0 && playback.flash < 1)
    clock.now = 1 + FocusRingModel.pulseDuration
    #expect(playback.flash == 0)
  }

  @Test func whenArborStopsEverythingIsGoneAtOnce() {
    let clock = Clock()
    let playback = OverlayPlayback(overlays) { clock.now }
    overlays.showHeadsUp(HeadsUpModel(kind: .hint, text: "Docked"), on: display)
    overlays.showDropPreview(screen)
    overlays.animate(transition([.init(window: WindowID(101), from: .zero, to: screen)]))
    clock.now = 0.2
    overlays.removeAll()
    #expect(playback.headsUpLine == nil)
    #expect(playback.dropPreview == nil)
    #expect(playback.stage(on: display) == nil)
  }
}

/// A film is a run of the real controller, written down.
@MainActor
@Suite struct FilmDirectorTests {
  private struct Film {
    var header: [String: Any]
    var frames: [[String: Any]]
    var text: String
    var failures: [String]
    var director: FilmDirector
  }

  private func film(_ script: String, fps: Int = 60) throws -> Film {
    let director = FilmDirector(fps: fps)
    var lines: [String] = []
    var failures: [String] = []
    director.write = { lines.append($0) }
    director.otherwise = { words in
      // The words of arbor-sim's that these scripts need.
      if words[0] == "mac-tiling" {
        director.harness.system.tiling = words[1] == "on" ? .on : .off
        return ("", true)
      }
      if words[0] == "open" {
        let size = words[2].split(separator: "x").compactMap { Double($0) }
        let origin = words[3].split(separator: ",").compactMap { Double($0) }
        let id = director.harness.system.open(
          app: words[1], pid: Int32(2000 + words[1].count), frame: CGRect(x: origin[0], y: origin[1], width: size[0], height: size[1]))
        return ("opened \(id)", true)
      }
      let result = director.harness.run(words.joined(separator: " "))
      return (result.message, result.ok)
    }
    for line in script.split(separator: "\n") where !director.run(String(line)).ok { failures.append(String(line)) }
    director.finish()
    let objects = try lines.map { line -> [String: Any] in
      let object = try JSONSerialization.jsonObject(with: Data(line.utf8))
      return try #require(object as? [String: Any])
    }
    return Film(header: objects[0], frames: Array(objects.dropFirst()), text: lines.joined(separator: "\n"), failures: failures,
      director: director)
  }

  private func rect(_ value: Any?) throws -> CGRect {
    let numbers = try #require(value as? [NSNumber]).map { CGFloat($0.doubleValue) }
    return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
  }

  private func window(_ id: Int, in frame: [String: Any]) throws -> CGRect {
    let windows = try #require(frame["windows"] as? [[String: Any]])
    let window = try #require(windows.first { $0["id"] as? Int == id })
    return try rect(window["frame"])
  }

  private let dragToTheLeftEdge = """
    display 1440x810 bar 24 dock 76
    app Browser #2f7bf6
    open Browser 800x500 300,100
    open Notes 400x300 700,300
    mac-tiling off
    launch
    pointer 900 700
    wait 0.5
    glide window 101 title in 0.5
    press
    glide 3 400 in 1
    wait 0.5
    lift
    wait 1
    """

  @Test func onAMacAsItComesTheEdgeIsMacOSsAndWhatItDoesThereIsFilmed() throws {
    let script = dragToTheLeftEdge.replacingOccurrences(of: "mac-tiling off", with: "mac-tiling on")
      .replacingOccurrences(of: "glide 3 400", with: "glide 0 400")
    let film = try film(script)
    #expect(film.failures.isEmpty)
    // Arbor stands aside: no preview, nothing docked, nothing moved by it.
    for key in ["preview", "backdrop", "stage"] { #expect(film.frames.allSatisfy { $0[key] == nil }) }
    // 0.5 + 0.5 + 1 + 0.5 s, then the button comes up: macOS grows the window to its half over a third of a second, in the film's time.
    let places = try film.frames.map { try window(101, in: $0) }
    let half = CGRect(x: 0, y: 24, width: 720, height: 710)
    let lifted = 150
    #expect(places[lifted].size == CGSize(width: 800, height: 500))
    let onTheWay = places[lifted + 10].width
    #expect(onTheWay < 800 && onTheWay > 720)
    #expect(places[lifted + 19] == half)
    #expect(places.last == half)
    #expect(film.frames.count == lifted + 18 + 60 + 1)
  }

  @Test func aModifierKeyIsHeldByItselfDuringADrag() throws {
    // ⌘ goes down once the window rests at the edge, under Arbor's preview, and comes up again before the button does.
    let script = dragToTheLeftEdge.replacingOccurrences(
      of: "wait 0.5\nlift", with: "wait 0.5\nkeydown cmd\nwait 0.5\nkeyup cmd\nwait 0.5\nlift")
    let film = try film(script)
    #expect(film.failures.isEmpty)
    // 0.5 + 0.5 + 1 + 0.5 s, then half a second with the key down.
    let (before, during, after) = (film.frames[145], film.frames[170], film.frames[205])
    #expect(before["keys"] == nil && after["keys"] == nil)
    let keys = try #require(during["keys"] as? [String: Any])
    #expect(keys["modifiers"] as? [String] == ["cmd"] && keys["key"] == nil && keys["label"] as? String == "⌘")
    // Arbor hears of the key at once, though the pointer rests: with ⌘ down it keeps out of the drag.
    let shown = [before, during, after].map { ($0["preview"] as? [String: Any])?["opacity"] as? NSNumber == 1 }
    #expect(shown == [true, false, true])
    #expect(film.director.harness.workspace.isDocked(WindowID(101)))

    // Let go of with ⌘ still down, the window floats where it lies.
    let kept = try self.film(dragToTheLeftEdge.replacingOccurrences(of: "wait 0.5\nlift", with: "keydown cmd\nwait 0.5\nlift\nkeyup cmd"))
    #expect(kept.failures.isEmpty)
    #expect(!kept.director.harness.workspace.isDocked(WindowID(101)))
  }

  @Test func whatIsHeldByItselfAndWhatAShortcutHoldsAreToldApart() throws {
    let film = try film(dragToTheLeftEdge)
    let (director, system) = (film.director, film.director.harness.system)
    func keys() -> [String: Any]? { director.camera.frame(number: 0, fps: 60)["keys"] as? [String: Any] }

    // By every name a shortcut knows them by; what is not held cannot be let go of.
    for line in ["keydown control+⌥", "keydown shift", "keyup alt+shift"] { #expect(director.run(line).ok, "\(line)") }
    #expect(system.heldModifiers == [.control] && director.camera.hands.modifiers == [.control])
    for line in ["keyup cmd", "keydown hyper", "keydown cmd+hyper", "keydown cmd+"] { #expect(!director.run(line).ok, "\(line)") }
    #expect(system.heldModifiers == [.control])

    // A shortcut that has the held key in it: when it comes up, the key held by itself is still down, for Arbor as in the film.
    #expect(director.run("tap ctrl+opt+return").ok)
    #expect(system.heldModifiers == [.control] && keys()?["modifiers"] as? [String] == ["ctrl"])
    // One that has not is another shortcut on a Mac: the film does not press it. Nor does it type.
    #expect(director.run("keydown cmd").ok)
    #expect(!director.run("tap ctrl+opt+space").ok)
    #expect(director.run("keyup ctrl+cmd").ok && keys() == nil && system.heldModifiers.isEmpty)
    #expect(director.run("tap ctrl+opt+g").ok && director.run("keydown shift").ok)
    #expect(!director.run("type a").ok && !director.run("tap return").ok)
    #expect(director.run("keyup shift").ok && director.run("tap escape").ok)

    // A shortcut that is held keeps its own modifier keys down whatever else comes and goes.
    #expect(director.run("keydown ctrl+opt+space").ok)
    #expect(director.run("keydown ctrl").ok && director.run("keyup ctrl").ok)
    #expect(system.heldModifiers == [.control, .option])
    #expect(keys()?["label"] as? String == "⌃⌥Space")
    #expect(director.run("keyup ctrl+opt+space").ok && system.heldModifiers.isEmpty)
  }

  @Test func withCommandDownATitleBarIsTakenHoldOfWithoutBringingTheWindowForward() throws {
    let film = try film(dragToTheLeftEdge + "\nglide window 102 visible in 0.1\nclick")
    let (director, system) = (film.director, film.director.harness.system)
    #expect(system.focused == WindowID(102))
    for line in ["keydown cmd", "glide window 101 title in 0.1", "press", "glide 500 300 in 0.2"] { #expect(director.run(line).ok, "\(line)") }
    #expect(director.camera.hands.landedOn == "the title bar of w101")
    #expect(system.focused == WindowID(102) && system.windowsFrontToBack().first == WindowID(102))
    for line in ["lift", "keyup cmd"] { #expect(director.run(line).ok) }
  }

  @Test func everySixtiethOfASecondIsOneLine() throws {
    let film = try film("display 1440x810\nwait 1.5\nwait 0.25")
    #expect(film.failures.isEmpty)
    // The last frame shows how things stand when the script is over.
    #expect(film.frames.count == 90 + 15 + 1)
    #expect(film.frames.enumerated().allSatisfy { $0.element["n"] as? Int == $0.offset })
    #expect(film.header["fps"] as? Int == 60)
    #expect(try rect((film.header["display"] as? [String: Any])?["visible"]) == CGRect(x: 0, y: 24, width: 1440, height: 786))
  }

  @Test func theSameScriptIsTheSameFilm() throws {
    #expect(try film(dragToTheLeftEdge).text == film(dragToTheLeftEdge).text)
  }

  @Test func aDraggedWindowFollowsThePointerAndThePreviewShowsAtTheEdge() throws {
    let film = try film(dragToTheLeftEdge)
    #expect(film.failures.isEmpty)
    // Half-way through the drag, which lasts from 1 s to 2 s.
    let midway = film.frames[90]
    let pointer = try #require((midway["pointer"] as? [String: Any])?["at"] as? [NSNumber]).map { CGFloat($0.doubleValue) }
    #expect((midway["pointer"] as? [String: Any])?["down"] as? Bool == true)
    let dragged = try window(101, in: midway)
    #expect(abs(dragged.midX - pointer[0]) < 0.02)
    #expect(abs(dragged.minY + 14 - pointer[1]) < 0.02)
    #expect(midway["preview"] == nil)

    let resting = film.frames[140]
    let preview = try #require(resting["preview"] as? [String: Any])
    #expect(preview["opacity"] as? Int == 1)
    #expect(try rect(preview["frame"]).minX == 12)
  }

  @Test func afterTheDropTheWindowIsDockedAndTheStandInsHandOverWithoutAJump() throws {
    let film = try film(dragToTheLeftEdge)
    let staged = film.frames.filter { $0["stage"] != nil }
    // 0.46 s of motion and 0.08 s of lifting.
    #expect((31...34).contains(staged.count))
    let last = try #require(staged.last)
    #expect(try #require((last["stage"] as? [String: Any])?["opacity"] as? NSNumber).doubleValue < 1)
    for standIn in try #require((last["stage"] as? [String: Any])?["standIns"] as? [[String: Any]]) {
      let id = try #require(standIn["id"] as? Int)
      let real = try window(id, in: last)
      #expect(near(try rect(standIn["frame"]), real, within: 1), "the stand-in of \(standIn["id"] ?? "?") ends beside its window")
      #expect(standIn["cover"] as? Int == 1)
    }
    // The real window went straight to its place when the button came up, under the stage.
    let first = try #require(staged.first)
    let end = try #require(film.frames.last)
    #expect(try window(101, in: first) == window(101, in: end))
    #expect(try window(101, in: first).minX == 12)
    #expect(end["ring"] != nil)
    #expect(end["backdrop"] != nil)
    #expect((end["headsUp"] as? [String: Any])?["text"] as? String == "Docked")
  }

  @Test func whatArborPutsOffHappensInItsTime() throws {
    let film = try film(dragToTheLeftEdge + "\nwait 3")
    // The line stays for a glance and fades by itself.
    #expect(try #require(film.frames.last)["headsUp"] == nil)
  }

  @Test func keysAreDownWhileTheyAreDownAndTheShortcutRuns() throws {
    let film = try film(dragToTheLeftEdge + "\ntap ctrl+opt+return\nwait 1")
    #expect(film.failures.isEmpty)
    let held = film.frames.filter { $0["keys"] != nil }
    #expect(held.count == 7)
    let keys = try #require(held[0]["keys"] as? [String: Any])
    #expect(keys["modifiers"] as? [String] == ["ctrl", "opt"])
    #expect(keys["key"] as? String == "return")
    let end = try #require(film.frames.last)
    #expect(try window(101, in: end).width == 1416)
  }

  @Test func aShortcutArborRefusesFailsTheLine() throws {
    #expect(try film("display 1440x810\nlaunch\ntap ctrl+opt+up").failures == ["tap ctrl+opt+up"])
  }

  @Test func theMenuOpensFromTheItemAndAChoiceRunsItsCommand() throws {
    let film = try film(
      dragToTheLeftEdge + """

        glide window 102 middle
        click
        glide item menu
        click
        wait 0.2
        glide menu Keep This Window in View
        wait 0.2
        click
        wait 0.5
        """)
    #expect(film.failures.isEmpty)
    let open = try #require(film.frames.last { $0["menu"] != nil })
    let rows = try #require((open["menu"] as? [String: Any])?["rows"] as? [[String: Any]])
    #expect(rows.first { $0["highlighted"] as? Bool == true }?["title"] as? String == "Keep This Window in View")
    #expect(rows.contains { $0["title"] as? String == "Show Everything" && $0["shortcut"] as? String == "⌃⌥Space" })
    let end = try #require(film.frames.last)
    #expect(end["menu"] == nil)
    #expect((end["headsUp"] as? [String: Any])?["text"] as? String == "Keeping Notes in view")
  }

  @Test func theItemIsInTheMenuBarFromLaunchToQuitAndQuittingGivesTheWindowBack() throws {
    let film = try film(dragToTheLeftEdge + "\nquit\nwait 0.1")
    #expect(film.frames[0]["menuBar"] != nil)
    #expect((film.frames[0]["menuBar"] as? [String: Any])?["icon"] != nil)
    let docked = film.frames[film.frames.count - 10]
    #expect(((docked["menuBar"] as? [String: Any])?["buttons"] as? [[String: Any]])?.count == 5)
    let end = try #require(film.frames.last)
    #expect(end["menuBar"] == nil)
    #expect(end["ring"] == nil)
    #expect(end["backdrop"] == nil)
    #expect(try window(101, in: end).size == CGSize(width: 800, height: 500))
  }

  @Test func goToIsTypedIntoAKeyAtATime() throws {
    let film = try film(dragToTheLeftEdge + "\ntap ctrl+opt+g\nwait 0.2\ntype no each 0.2\ntap return\nwait 0.6")
    #expect(film.failures.isEmpty)
    let texts = film.frames.compactMap { ($0["goTo"] as? [String: Any])?["text"] as? String }
    #expect(Set(texts) == ["", "n", "no"])
    let typed = try #require(film.frames.last { $0["goTo"] != nil })
    let rows = try #require((typed["goTo"] as? [String: Any])?["rows"] as? [[String: Any]])
    #expect(rows.map { $0["name"] as? String } == ["Notes"])
    #expect(rows[0]["selected"] as? Bool == true)
    #expect(try #require(film.frames.last)["goTo"] == nil)
  }

  @Test func theColourOfAnAppIsWhatArborTakesFromItsIcon() throws {
    // A white tile with a red glyph, which averages to pink: Arbor takes the red.
    var bytes = Data()
    for pixel in 0..<(24 * 24) { bytes.append(contentsOf: pixel % 4 == 0 ? [220, 30, 30, 255] : [255, 255, 255, 255]) }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-film-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try bytes.write(to: folder.appendingPathComponent("icon.rgba"))

    let director = FilmDirector()
    director.folder = folder
    #expect(director.run("app Notes icon icon.rgba").ok)
    let colour = try #require(director.camera.appColours["Notes"])
    #expect(abs(colour.red - 220 / 255) < 1e-6 && abs(colour.green - 30 / 255) < 1e-6 && abs(colour.blue - 30 / 255) < 1e-6)
    #expect(!director.run("app Notes icon missing.rgba").ok)
    #expect(director.run("app Mail #55c4ee").ok)
    #expect(!director.run("app Mail blue").ok)
  }

  @Test func withPicturesOfWindowsSwitchedOnTheStandInsArePictures() throws {
    let film = try film("set windowPictures true\n" + dragToTheLeftEdge)
    let staged = try #require(film.frames.first { $0["stage"] != nil })
    let standIns = try #require((staged["stage"] as? [String: Any])?["standIns"] as? [[String: Any]])
    #expect(standIns.allSatisfy { $0["picture"] as? Int == 1 && $0["cover"] as? Int == 0 })
  }

  @Test func aPressOnAnythingEndsAMotion() throws {
    let film = try film(dragToTheLeftEdge + "\nglide item menu in 0.3\ntap ctrl+opt+return for 0.05\nwait 0.1\npress\nwait 0.2\nlift")
    #expect(film.failures.isEmpty)
    let pressed = try #require(film.frames.firstIndex { ($0["pointer"] as? [String: Any])?["down"] as? Bool == true && ($0["n"] as? Int ?? 0) > 200 })
    #expect(film.frames[pressed - 1]["stage"] != nil)
    #expect(film.frames[pressed]["stage"] == nil)
  }

  @Test func aClickPutsThePanelOfShortcutsAndGoToAway() throws {
    let film = try film(
      dragToTheLeftEdge + "\ntap ctrl+opt+shift+/\nwait 0.3\nglide window 101 middle in 0.2\nclick\nwait 0.2\ntap ctrl+opt+g\nwait 0.2\nclick\nwait 0.2")
    #expect(film.failures.isEmpty)
    #expect(film.frames.contains { $0["shortcuts"] != nil })
    #expect(film.frames.contains { $0["goTo"] != nil })
    let end = try #require(film.frames.last)
    #expect(end["shortcuts"] == nil)
    #expect(end["goTo"] == nil)
  }

  @Test func aClickOnARowOfGoToChoosesIt() throws {
    let director = FilmDirector()
    let a = director.harness.system.open(app: "Browser", pid: 2001)
    let b = director.harness.system.open(app: "Notes", pid: 2002)
    for line in ["launch", "dock \(a.rawValue) left", "dock \(b.rawValue) right", "zoom \(a.rawValue)", "tap ctrl+opt+g"] {
      #expect(director.run(line).ok)
    }
    let palette = try #require(director.harness.overlays.finder)
    let place = try #require(palette.items.firstIndex { $0.row.destination == .window(b) })
    let row = palette.layout.rowFrame(place).offsetBy(
      dx: palette.layout.panel.minX + palette.layout.list.minX, dy: palette.layout.panel.minY + palette.layout.list.minY)
    #expect(director.run("pointer \(row.midX) \(row.midY)").ok)
    #expect(director.run("click").message == "clicked Go to…")
    #expect(director.harness.overlays.finder == nil)
    #expect(director.harness.system.focused == b)
  }

  @Test func theHandleOfAGapThatIsDraggedStaysInTheGap() throws {
    let film = try film(
      """
      display 1440x810 bar 24
      open Browser 800x500 100,100
      open Notes 400x300 700,300
      launch
      dock 101 left
      dock 102 right
      float 102
      dock 102 right
      pointer 482 400
      wait 0.1
      press
      glide 700 400 in 0.4
      wait 0.1
      lift
      """)
    #expect(film.failures.isEmpty)
    let dragged = film.frames.filter { ($0["gapHandle"] as? [String: Any])?["dragged"] as? Bool == true }
    #expect(dragged.count > 20)
    for frame in dragged {
      // The pill's outline begins with its leftmost x or thereabouts: it lies right of the window the gap follows.
      let path = try #require((frame["gapHandle"] as? [String: Any])?["path"] as? String)
      let x = try #require(Double(path.dropFirst().prefix { $0 != " " }))
      let edge = try window(101, in: frame).maxX
      #expect(CGFloat(x) >= edge && CGFloat(x) <= edge + 12, "the pill at \(x) is not in the gap that begins at \(edge)")
    }
  }

  @Test func aKeyThatIsRefusedDuringADragIsNotHeldAgainstTheDrop() throws {
    let film = try film(dragToTheLeftEdge.replacingOccurrences(of: "wait 0.5\nlift", with: "tap ctrl+opt+up\nwait 0.5\nlift"))
    #expect(film.failures == ["tap ctrl+opt+up"])
  }

  @Test func linesOfTheSimulatorsThatShareAVerbReachIt() {
    let director = FilmDirector()
    var passedOn: [[String]] = []
    director.otherwise = { words in
      passedOn.append(words)
      return ("", true)
    }
    for line in ["press zoom 101", "display main gap 30", "type", "click here"] { _ = director.run(line) }
    #expect(passedOn.map { $0.joined(separator: " ") } == ["press zoom 101", "display main gap 30", "type", "click here"])
    #expect(!director.harness.system.mouseDown)
  }

  @Test func aFilmShowsOneDisplay() {
    let director = FilmDirector()
    #expect(!director.run("displays 0").ok)
    #expect(!director.run("displays 2").ok)
    #expect(director.harness.system.displayList.count == 1)
  }

  @Test func thePointerStaysOnTheDisplay() throws {
    let film = try film(dragToTheLeftEdge + "\ntap ctrl+opt+return\nwait 0.6\nglide window 102 middle in 0.3\nclick")
    #expect(film.failures.isEmpty)
    let end = try #require(film.frames.last)
    let at = try #require((end["pointer"] as? [String: Any])?["at"] as? [NSNumber])
    // It went as far as it could: to the edge past which the window is.
    #expect(at[0].doubleValue == 1439 && at[1].doubleValue <= 809)
  }

  @Test func aClickOnTheBareDesktopTakesTheKeyboardFromTheWindows() throws {
    let film = try film(dragToTheLeftEdge + "\nglide 1300 150 in 0.3\nclick\nwait 0.3")
    let end = try #require(film.frames.last)
    #expect(end["ring"] == nil)
    #expect(try #require(end["windows"] as? [[String: Any]]).allSatisfy { $0["focused"] == nil })
  }

  @Test func whatHoldsForTheWholeFilmIsSaidBeforeTheFirstFrame() throws {
    let film = try film("display 1440x810\naccent #ff0000\nwait 0.1\naccent #00ff00\napp Mail #55c4ee\ndisplay 1920x1080\nreserve 10")
    #expect(film.failures == ["accent #00ff00", "app Mail #55c4ee", "display 1920x1080", "reserve 10"])
    #expect(film.header["accent"] as? String == "rgba(255,0,0,1.0)")
  }

  @Test func aFilmIsAsLongAsItsLinesSayAtAnyFrameRate() throws {
    let script = "display 1440x810\n" + String(repeating: "wait 0.09\nwait 0.005\n", count: 40)
    #expect(try film(script, fps: 60).frames.count == 228 + 1)
    #expect(try film(script, fps: 30).frames.count == 114 + 1)
  }

  @Test func thePointerGoesForAPartOfTheWindowThatCanBeSeen() {
    let director = FilmDirector()
    let system = director.harness.system
    let behind = system.open(app: "Mail", pid: 2001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let front = system.open(app: "Notes", pid: 2002, frame: CGRect(x: 300, y: 60, width: 500, height: 300))
    system.userFocus(front)

    // The middle of the title bar and of the window are under Notes: the pointer goes beside it.
    #expect(director.run("glide window \(behind.rawValue) title in 0.1").ok)
    #expect(director.camera.hands.window(at: system.cursor) == behind)
    #expect(system.cursor.y == 114 && system.cursor.x < 300 && system.cursor.x > 176)
    #expect(director.run("glide window \(behind.rawValue) visible in 0.1").ok)
    #expect(director.camera.hands.window(at: system.cursor) == behind)
    #expect(director.run("click").message == "clicked \(behind)")

    // Nobody can take hold of what is wholly covered, or out of view.
    system.userMove(front, to: CGRect(x: 50, y: 50, width: 900, height: 600))
    system.userFocus(front)
    #expect(!director.run("glide window \(behind.rawValue) title").ok)
    #expect(!director.run("glide window \(behind.rawValue) visible").ok)
    system.userMove(front, to: CGRect(x: 1439, y: 700, width: 500, height: 300))
    #expect(!director.run("glide window \(front.rawValue) title").ok)
  }

  @Test func whatLiesUnderGoToOrAnOpenMenuCannotBeReached() throws {
    let film = try film(dragToTheLeftEdge + "\ntap ctrl+opt+g\nwait 0.3")
    #expect(film.failures.isEmpty)
    let director = film.director
    let panel = try #require(director.harness.overlays.finder?.layout.panel)
    let under = WindowID(102)
    director.harness.system.userMove(under, to: panel.insetBy(dx: 30, dy: 30))
    #expect(director.harness.overlays.finder != nil)
    #expect(!director.run("glide window 102 visible").ok)
    #expect(!director.run("glide window 102 title").ok)

    // What looks out from under the panel can be reached there: the click closes the panel and is the window's.
    director.harness.system.userMove(under, to: panel.insetBy(dx: 30, dy: 30).offsetBy(dx: 0, dy: panel.height / 2))
    #expect(director.run("glide window 102 visible in 0.1").ok)
    #expect(!panel.contains(director.harness.system.cursor))
    #expect(director.run("click").message == "clicked \(under)")
    #expect(director.harness.overlays.finder == nil)

    #expect(director.run("glide item menu in 0.1").ok)
    #expect(director.run("click").ok)
    #expect(!director.run("glide window 102 visible").ok)
  }

  @Test func theFilmsOwnNotesTravelWithEveryFrameUntilTheyChange() throws {
    let film = try film("display 1440x810\ncaption Windows pile up.\nwait 0.1\ncaption\nmark badge.Chat 1\nwait 0.1")
    #expect((film.frames[0]["marks"] as? [String: String]) == ["caption": "Windows pile up."])
    #expect((try #require(film.frames.last)["marks"] as? [String: String]) == ["badge.Chat": "1"])
  }
}

#if os(macOS)
  /// `StagePlayback` and `OverlayPlayback` repeat numbers of views that do not build without AppKit. Here, where both build, they are
  /// held against each other.
  @MainActor
  @Suite struct StageTimingTests {
    @Test func theNumbersAreTheViewsOwn() {
      #expect(StagePlayback.liftDuration == Stage.liftDuration)
      #expect(OverlayPlayback.previewMotion == AppKitOverlays.previewMotion)
      #expect(OverlayPlayback.passingFadeIn == PassingPanel.fadeIn)
      #expect(OverlayPlayback.passingFadeOut == PassingPanel.fadeOut)
      #expect(OverlayPlayback.passingFadeIn == MinimapPanel.fadeIn)
      #expect(OverlayPlayback.passingFadeOut == MinimapPanel.fadeOut)
      #expect(OverlayPlayback.backdropFade == BackdropLayer.fade)
      // A film shows macOS 26.
      if #available(macOS 26, *) { #expect(FilmCamera.windowRadius == ContinuousCorners.windowRadius) }
    }
  }
#endif
