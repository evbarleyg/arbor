import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// Plays a film script against the real controller and has a `FilmCamera` write down every frame (docs/FILM.md).
///
/// A script is a list of lines like arbor-sim's. Lines that take time (`wait`, `glide`, `click`, `tap`, `type`) are filmed while
/// they last; every other line happens between two frames. What the director does not know it hands to `otherwise`,
/// which in arbor-sim is the simulator's whole vocabulary.
@MainActor
public final class FilmDirector {
  public typealias Outcome = (message: String, ok: Bool)

  public let harness: Harness
  public let camera: FilmCamera
  public let fps: Int
  /// Gets the header and then every frame, one line of JSON each.
  public var write: (String) -> Void = { _ in }
  /// Runs a line that is not the director's own.
  public var otherwise: ([String]) -> Outcome
  /// Where the script is, for the files it names.
  public var folder = URL(fileURLWithPath: ".")
  /// How many frames have been written.
  public private(set) var frames = 0
  private var wroteHeader = false
  /// The scheduler's time at frame 0. It moves on when a line lets time pass unseen.
  private var base = 0.0
  /// How long the film should be by now, in seconds, going by its lines.
  private var due = 0.0
  private var hands: FilmHands { camera.hands }

  /// How long the button is down in a click, and a key in a tap.
  static let clickTime = 0.09
  static let tapTime = 0.12

  public init(harness: Harness = Harness(), fps: Int = 60) {
    self.harness = harness
    self.fps = max(fps, 1)
    camera = FilmCamera(harness)
    otherwise = { [harness] words in
      let result = harness.run(words.joined(separator: " "))
      return ((result.ok ? "" : "error: ") + result.message, result.ok)
    }
    hands.onQuit = { [weak self] in self?.quit() }
    // What macOS or an app takes its time over (a window grown to macOS's own tile, the way out of full screen) is filmed as well: no
    // time passes between two frames but a frame's.
    harness.system.passTime = { [weak self] in self?.pass($0) }
  }

  // MARK: Time

  private func shoot() {
    if !wroteHeader {
      wroteHeader = true
      write(FilmCamera.line(camera.header(fps: fps)))
    }
    write(FilmCamera.line(camera.frame(number: frames, fps: fps)))
    frames += 1
  }

  /// Films `seconds`. After each frame the clock moves on, and `then` hears how much of the time is over, up to 1.
  ///
  /// Time moves in whole frames. What a line's time leaves over or lacks is carried to the next, so that a film is as long as its lines say
  /// at any frame rate; a moment within it can still fall a frame earlier or later at another rate.
  private func pass(_ seconds: Double, then: ((Double) -> Void)? = nil) {
    due += seconds
    let steps = Int((due * Double(fps)).rounded()) - frames
    guard steps > 0 else {
      then?(1)
      return
    }
    for step in 1...steps {
      shoot()
      harness.scheduler.advance(by: max(base + Double(frames) / Double(fps) - harness.scheduler.now, 0))
      then?(Double(step) / Double(steps))
      settle()
    }
  }

  /// What arbor-sim does after every line: macOS reports back what Arbor asked for, and what Arbor put off until the event is over happens.
  private func settle() {
    harness.system.deliverEchoes()
    harness.scheduler.advance(by: 0)
  }

  /// The last frame: how things stand when the script is over.
  public func finish() { shoot() }

  // MARK: Lines

  public func run(_ line: String) -> Outcome {
    let words = line.split(separator: " ").map(String.init)
    guard let verb = words.first else { return ("", true) }
    // The camera looks at one display, which has to be there.
    if verb == "displays", words.count > 1, words[1] != "1" { return ("error: a film shows one display", false) }
    let outcome = perform(verb, Array(words.dropFirst())) ?? otherwise(words)
    settle()
    // A line of the simulator's may have let time pass. The film goes on from there without a gap.
    base = harness.scheduler.now - Double(frames) / Double(fps)
    return outcome
  }

  private func number(_ word: String?) -> Double? {
    word.flatMap(Double.init).flatMap { $0.isFinite && abs($0) <= 1_000_000 ? $0 : nil }
  }

  /// Takes `<word> <seconds>` off the end of `words`.
  private func seconds(after word: String, in words: inout [String]) -> Double? {
    guard words.count >= 2, words[words.count - 2] == word, let value = number(words.last), (0...60).contains(value) else {
      return nil
    }
    words.removeLast(2)
    return value
  }

  private func colour(_ word: String?) -> RGBA? {
    guard case .rgba(let red, let green, let blue, let alpha)? = word.flatMap(FocusRingColour.init(text:)) else { return nil }
    return RGBA(red: red, green: green, blue: blue, alpha: alpha)
  }

  private func report(_ result: CommandResult?, or text: String) -> Outcome {
    guard let result else { return (text, true) }
    return ((result.ok ? "" : "error: ") + result.message, result.ok)
  }

  /// Nil for a verb that is not the director's.
  private func perform(_ verb: String, _ rest: [String]) -> Outcome? {
    var rest = rest
    // The simulator has lines of the same name that take other words: `press <command>`, `display <match> <key> <value>`, `type`.
    if ["press", "lift", "click", "launch"].contains(verb), !rest.isEmpty { return nil }
    if verb == "display", rest.first?.first?.isNumber != true { return nil }
    if verb == "type", rest.isEmpty { return nil }
    // The first line of a film says what holds for all of it.
    if ["display", "app", "accent", "reserve"].contains(verb), wroteHeader {
      return ("error: `\(verb)` holds for the whole film: say it before the first frame", false)
    }
    switch verb {
    case "display":
      return setDisplay(rest)
    case "app":
      return setApp(rest)
    case "accent":
      guard rest.count == 1, let colour = colour(rest[0]) else { return ("usage: accent <#rrggbb>", false) }
      camera.accent = colour
      return ("the accent colour is \(rest[0])", true)
    case "reserve":
      guard rest.count == 1, let points = number(rest[0]), points >= 0 else { return ("usage: reserve <points>", false) }
      hands.menuBarReserve = CGFloat(points)
      return ("the other menu bar items take \(rest[0]) points", true)
    case "mark", "caption", "shot":
      if verb == "mark", rest.isEmpty { return ("usage: mark <name> [text]", false) }
      let name = verb == "mark" ? rest.removeFirst() : verb
      camera.marks[name] = rest.isEmpty ? nil : rest.joined(separator: " ")
      return (rest.isEmpty ? "\(name) cleared" : "\(name): \(rest.joined(separator: " "))", true)
    case "launch":
      harness.start()
      hands.arborIsInTheMenuBar = true
      return ("Arbor is running", true)
    case "quit":
      guard rest.isEmpty else { return nil }
      quit()
      return ("Arbor has quit", true)
    case "wait":
      guard rest.count == 1, let seconds = number(rest[0]), (0...600).contains(seconds) else {
        return ("usage: wait <seconds>", false)
      }
      pass(seconds)
      return ("\(rest[0]) s later", true)
    case "pointer":
      guard rest.count == 2, let x = number(rest[0]), let y = number(rest[1]) else { return ("usage: pointer <x> <y>", false) }
      hands.move(to: CGPoint(x: x, y: y))
      return ("the pointer is at \(rest[0]),\(rest[1])", true)
    case "glide":
      return glide(rest)
    case "press":
      hands.press()
      return ("the button is down on \(hands.landedOn)", true)
    case "lift":
      hands.lift()
      return report(hands.pointerResult, or: "the button is up")
    case "click":
      hands.press()
      settle()
      pass(Self.clickTime)
      hands.lift()
      return report(hands.pointerResult, or: "clicked \(hands.landedOn)")
    case "tap":
      let time = seconds(after: "for", in: &rest) ?? Self.tapTime
      guard rest.count == 1 else { return ("usage: tap <shortcut or key> [for <seconds>]", false) }
      return tap(rest[0], for: time)
    case "keydown", "keyup":
      // Modifier keys by themselves: held while something else happens, a drag mostly.
      if rest.count == 1, let modifiers = modifiers(rest[0]) {
        if verb == "keyup", !hands.modifiers.isSuperset(of: modifiers) { return ("error: \(rest[0]) is not held", false) }
        hands.hold(verb == "keydown" ? hands.modifiers.union(modifiers) : hands.modifiers.subtracting(modifiers))
        return ("\(verb == "keydown" ? "holding" : "let go of") \(rest[0])", true)
      }
      guard rest.count == 1, let chord = try? KeyChord(text: rest[0]) else {
        return ("usage: \(verb) <shortcut or modifier keys>, e.g. \(verb) ctrl+opt+space, \(verb) cmd", false)
      }
      if verb == "keyup" {
        hands.keyUp(chord)
        return ("let go of \(rest[0])", true)
      }
      return report(hands.keyDown(chord), or: "pressed \(rest[0])")
    case "type":
      let each = seconds(after: "each", in: &rest) ?? 0.16
      return type(rest.joined(separator: " "), each: each)
    default:
      return nil
    }
  }

  /// `cmd`, `ctrl+opt`…: nothing but modifier keys, by every name a shortcut knows them by. With a key after them they are a shortcut;
  /// what already has a key is none then.
  private func modifiers(_ text: String) -> KeyChord.Modifiers? {
    (try? KeyChord(text: text + "+space")).map(\.modifiers).flatMap { $0.isEmpty ? nil : $0 }
  }

  /// `app <Name> <#rrggbb>` says which colour Arbor takes from the app's icon. `app <Name> icon <file>` has Arbor take it: the file holds
  /// the icon as `AppAppearance.samples` sees it, 24 by 24 pixels of four bytes each: red, green, blue, alpha, colours not multiplied by alpha.
  private func setApp(_ words: [String]) -> Outcome {
    let usage: Outcome = ("usage: app <Name> <#rrggbb> | app <Name> icon <file of 24 x 24 RGBA pixels>", false)
    if words.count == 2, let colour = colour(words[1]) {
      camera.appColours[words[0]] = colour
      return ("the colour of \(words[0]) is \(words[1])", true)
    }
    guard words.count >= 3, words[1] == "icon" else { return usage }
    let path = words.dropFirst(2).joined(separator: " ")
    let file = path.hasPrefix("/") ? URL(fileURLWithPath: path) : folder.appendingPathComponent(path)
    guard let bytes = try? Data(contentsOf: file), bytes.count == 24 * 24 * 4 else {
      return ("error: \(path) is not a file of 24 x 24 pixels of four bytes", false)
    }
    let samples = stride(from: 0, to: bytes.count, by: 4).compactMap { at -> RGBA? in
      guard bytes[at + 3] > 0 else { return nil }
      return RGBA(
        red: Double(bytes[at]) / 255, green: Double(bytes[at + 1]) / 255, blue: Double(bytes[at + 2]) / 255,
        alpha: Double(bytes[at + 3]) / 255)
    }
    guard let colour = IconColour.dominant(of: samples) else { return ("error: the icon in \(path) is all transparent", false) }
    camera.appColours[words[0]] = colour
    return ("the colour of \(words[0]) is \(FilmCamera.colour(colour))", true)
  }

  /// `display <WxH> [bar <points>] [dock <points>]`: one display, with a menu bar and room for the Dock.
  private func setDisplay(_ words: [String]) -> Outcome {
    let usage: Outcome = ("usage: display <WxH> [bar <points>] [dock <points>]", false)
    let size = (words.first ?? "").lowercased().split(separator: "x").compactMap { number(String($0)) }
    guard size.count == 2, size[0] >= 640, size[1] >= 400, words.count % 2 == 1 else { return usage }
    var (bar, dock) = (24.0, 0.0)
    for index in stride(from: 1, to: words.count, by: 2) {
      guard let points = number(words[index + 1]), (0...200).contains(points) else { return usage }
      switch words[index] {
      case "bar": bar = points
      case "dock": dock = points
      default: return usage
      }
    }
    harness.system.setDisplays([
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: size[0], height: size[1]),
        visibleFrame: CGRect(x: 0, y: bar, width: size[0], height: size[1] - bar - dock), isMain: true)
    ])
    return ("the display is \(words[0])", true)
  }

  /// As `ArborApp.applicationWillTerminate` does.
  private func quit() {
    harness.controller.shutdown()
    hands.arborIsInTheMenuBar = false
  }

  // MARK: The pointer

  /// `glide <x> <y>`, `glide window <id> title|visible|middle|<share of width> <share of height>`, `glide gap <id> <id>`,
  /// `glide item [button]` (Arbor's menu bar item) or `glide menu <title>` (a row of its open menu), each with `in <seconds>` after it
  /// if the time matters.
  private func glide(_ words: [String]) -> Outcome {
    var words = words
    let time = seconds(after: "in", in: &words)
    let usage =
      "usage: glide <x> <y> | window <id> title|visible|middle|<fx> <fy> | gap <id> <id> | item [button] | menu <title>, then [in <seconds>]"
    let target: CGPoint?
    switch words.first {
    case "window":
      guard words.count >= 3, let id = WindowID(word: words[1]), let frame = harness.system.frame(of: id) else {
        return (usage, false)
      }
      if words.count == 3, words[2] == "title" || words[2] == "visible" {
        // Where a person would take hold of it, or click it: a part they can see.
        target = hands.reachableSpot(of: id, titleBar: words[2] == "title")
        if target == nil { return ("error: \(words[2] == "title" ? "the title bar" : "all") of \(id) is covered or out of view", false) }
      } else if words.count == 3, words[2] == "middle" {
        target = frame.center
      } else if words.count == 4, let x = number(words[2]), let y = number(words[3]) {
        target = CGPoint(x: frame.minX + frame.width * x, y: frame.minY + frame.height * y)
      } else {
        return (usage, false)
      }
    case "gap":
      guard words.count == 3, let first = WindowID(word: words[1]), let second = WindowID(word: words[2]) else { return (usage, false) }
      target = hands.gapSpot(between: first, and: second)
      if target == nil { return ("error: \(first) and \(second) have no gap between them that can be reached", false) }
    case "item":
      guard words.count <= 2 else { return (usage, false) }
      target = hands.statusItemSpot(words.count == 2 ? words[1] : nil)
      if target == nil { return ("error: the menu bar item has no button \(words.last ?? "")", false) }
    case "menu":
      let title = words.dropFirst().joined(separator: " ")
      target = hands.menuSpot(title)
      if target == nil { return ("error: the open menu has no item \(title)", false) }
    default:
      guard words.count == 2, let x = number(words[0]), let y = number(words[1]) else { return (usage, false) }
      target = CGPoint(x: x, y: y)
    }
    guard let target else { return (usage, false) }

    let start = hands.pointer
    let distance = Double(hypot(target.x - start.x, target.y - start.y))
    // A hand takes longer for a longer way, but not in proportion.
    pass(time ?? min(max(0.3 + distance / 1500, 0.3), 1.1)) { share in
      // A hand starts and stops gently: the smoothest way from rest to rest.
      let eased = CGFloat(share * share * share * (10 - 15 * share + 6 * share * share))
      self.hands.move(
        to: CGPoint(x: start.x + (target.x - start.x) * eased, y: start.y + (target.y - start.y) * eased))
    }
    return ("the pointer is at \(Int(target.x.rounded())),\(Int(target.y.rounded()))", true)
  }

  // MARK: The keyboard

  /// A shortcut, or a plain key for the palette that has the keyboard.
  private func tap(_ text: String, for time: Double) -> Outcome {
    if let outcome = plainKey(text, for: time) { return outcome }
    guard let chord = try? KeyChord(text: text) else { return ("cannot read the shortcut \(text)", false) }
    let result = hands.keyDown(chord)
    settle()
    pass(time)
    hands.keyUp(chord)
    return report(result, or: "pressed \(text)")
  }

  /// ↩, ⎋, ⇥ and the arrows while Go to… is open go to it, as any key without ⌃⌥ does.
  private func plainKey(_ name: String, for time: Double) -> Outcome? {
    let overlays = harness.overlays
    if name == "escape", hands.menu != nil {
      hands.typingKey = name
      hands.closeMenu()
      pass(time)
      hands.typingKey = nil
      return ("the menu is closed", true)
    }
    guard overlays.finder != nil, ["return", "escape", "up", "down", "tab"].contains(name) else { return nil }
    guard hands.modifiers.isEmpty else { return ("error: a modifier key is held: with it \(name) is another key", false) }
    var ok = true
    hands.typingKey = name
    switch name {
    case "return": ok = overlays.chooseInFinder()
    case "escape": overlays.dismissFinder()
    case "up": overlays.moveFinderSelection(by: -1)
    default: overlays.moveFinderSelection(by: 1)
    }
    settle()
    pass(time)
    hands.typingKey = nil
    return (ok ? "pressed \(name)" : "error: nothing to choose there", ok)
  }

  /// Types into Go to…, a key at a time.
  private func type(_ text: String, each: Double) -> Outcome {
    guard let finder = harness.overlays.finder else { return ("error: nothing is open to type into; `find` opens Go to…", false) }
    guard hands.modifiers.isEmpty else { return ("error: a modifier key is held: what is typed with it is no letter", false) }
    var typed = finder.query
    for character in text {
      typed.append(character)
      hands.typingKey = character == " " ? "space" : String(character)
      harness.overlays.typeInFinder(typed)
      pass(min(Self.tapTime, each))
      hands.typingKey = nil
      pass(max(each - Self.tapTime, 0))
    }
    return (harness.overlays.finder?.text ?? "", true)
  }
}
