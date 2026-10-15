import ArborCore
import CoreGraphics
import Foundation

/// A docked window that Arbor takes from one display to another.
///
/// Right after a position call has taken a window across, macOS judges a size call by the display the window came from: under 6 ms 10 of
/// 10, from 200 ms on by the new one, 4 of 4, in every order of the calls (a probe on a hosted Mac, macOS 26). From 1280×720 to 1920×1080 a
/// window asked to be 947 high at y 43 took 677: 720 − 43, the foot of the display it had left. Asked again a millisecond later: 677. Arbor
/// took that for an app that will not grow, centred the window in its slot and wrote the short size down, and so it lay until it next
/// went out of view.
///
/// That is the screen's answer and not the window's. It is never written down and never taken for a refusal, the window stays at its slot's
/// corner meanwhile, and it is asked again when macOS has caught up: a quarter of a second after the journey, and as long as it is still as short as
/// another display would have it, half a second and a second after it. What it answers then is its own answer, like any other.
extension Controller {
  /// A window that came out short after a journey, as short as another display would have it.
  struct Journey {
    /// On which display it is to be.
    var display: DisplayID
    /// How often it has been asked again.
    var askedAgain = 0
    /// For a window that is not docked: the frame it is to have, and the one it has for now.
    var owed: (wanted: CGRect, has: CGRect)?
  }

  /// When it is asked again, counted from the answer before: a quarter of a second after the journey, half a second and a second after it. All
  /// that Macs have said is that the old display judged no more after 200 ms, once: one that takes 300 is not to show a short window for a second.
  static let timesToCatchUp: [TimeInterval] = [0.25, 0.25, 0.5]

  /// One for each display, like the wait for a window that is only just back (`postponesJudgement`).
  private func askAgainKey(_ display: DisplayID) -> String { "across-\(display.rawValue)" }

  /// Whether `answer`, which is short of `slot` on `display`, may be what another display made of the asking. Wherever the window stood when
  /// it was asked: it may have been taken across by a call that only moved it, and be asked to grow by the next layout, within the same moment.
  func isAnotherDisplaysAnswer(_ answer: CGRect, shortOf slot: CGRect, on display: DisplayID) -> Bool {
    let kept = sidesAnotherDisplayKept(of: answer.size, shortOf: slot.size, at: [answer.origin], on: display)
    return kept.width || kept.height
  }

  /// Which sides of a window that `took` less than it was `asked` for another display than `display` may have kept short: judged by that one's
  /// lines, with its corner at one of `origins`, macOS lets it be no larger than it is (`ScreenLines`, as in `sidesTheScreenKept`). So it ends
  /// on such a line, or in the strip of that display's Dock, where a window keeps the height it has. Each side by itself. By which display
  /// macOS counts a window that straddles two nobody has measured, so any other will do.
  func sidesAnotherDisplayKept(
    of took: CGSize, shortOf asked: CGSize, at origins: [CGPoint], on display: DisplayID
  ) -> (width: Bool, height: Bool) {
    var (width, height) = (false, false)
    for other in displays where other.id != display {
      for origin in origins {
        let allowed = other.lines.allows(asked, to: CGRect(origin: origin, size: took))
        if took.width < asked.width - 2, allowed.width < asked.width, allowed.width <= took.width + Self.theDocksPlay { width = true }
        if took.height < asked.height - 2, allowed.height < asked.height, allowed.height <= took.height + Self.theDocksPlay { height = true }
      }
    }
    return (width, height)
  }

  /// The windows that are short for now and are going to be asked again, for whoever compares windows with the layout. Only while the time until
  /// then is running.
  public var windowsToBeAskedAgain: Set<WindowID> { Set(journeys.filter { displaysToAskAgain.contains($0.value.display) }.keys) }

  /// Gives `window` the frame it is to have, which is not a slot: its own size, where a hand left it (`giveAtOnce`). Fresh from another display
  /// it comes out short. What it is to write down as its own is then what was asked for, since a size written down is lost for good; and
  /// it is given the frame again when macOS has caught up.
  func give(_ frame: CGRect, to window: WindowID) -> Given? {
    // It may be sized somewhere else than where it ends up, and is judged where it was sized.
    let before = windows[window].flatMap { whereItHasToBeSized(for: frame, from: $0.frame) }
    guard var given = giveAtOnce(frame, to: window) else {
      // An asking that gets no answer ends the series: every call to an app that hangs holds the main thread.
      journeyIsOver(window)
      return nil
    }
    guard let display = stopper(of: given.frame.origin)?.id else { return given }
    let places = [given.frame.origin, before, whereItHasToBeSized(for: frame, from: given.frame)].compactMap { $0 }
    let kept = sidesAnotherDisplayKept(of: given.frame.size, shortOf: frame.size, at: places, on: display)
    guard kept.width || kept.height, askAgainAfterTheJourney(window, on: display) else {
      journeyIsOver(window)
      return given
    }
    if kept.width { given.own.size.width = frame.width }
    if kept.height { given.own.size.height = frame.height }
    journeys[window]?.owed = (frame, given.frame)
    return given
  }

  /// Called for such an answer. True if nothing is to be made of it: the window is going to be asked again. False if it has been asked often
  /// enough: macOS has long caught up, and this is its own answer.
  func askAgainAfterTheJourney(_ window: WindowID, on display: DisplayID) -> Bool {
    if journeys[window]?.display != display {
      journeyIsOver(window)
      journeys[window] = Journey(display: display)
    }
    guard let journey = journeys[window], journey.askedAgain < Self.timesToCatchUp.count else {
      Log.info("\(window) is as short as another display would have it a second after it came to display \(display): that is its own answer")
      return false
    }
    // A layout that comes meanwhile asks too, and ends here. The time that is running goes on running.
    if !displaysToAskAgain.contains(display) { askAgain(on: display, after: Self.timesToCatchUp[journey.askedAgain]) }
    return true
  }

  private func askAgain(on display: DisplayID, after seconds: TimeInterval, havingWaited turns: Int = 0) {
    displaysToAskAgain.insert(display)
    scheduler.schedule(askAgainKey(display), after: seconds) { [weak self] in
      guard let self else { return }
      self.displaysToAskAgain.remove(display)
      let waiting = self.journeys.filter { $0.value.display == display }.keys.sorted()
      guard self.isRunning else { return waiting.forEach(self.journeyIsOver) }
      // Not under a hand, like any put-back (`scheduleEnforce`), however long it holds: no layout need follow when it lets go.
      if self.system.isMouseButtonDown() || self.isAwaitingResizeEnd(on: display) {
        return self.askAgain(on: display, after: 0.25, havingWaited: turns)
      }
      // Nor by displays that may be gone, nor while somebody leaves full screen. For ten seconds: either ends in a layout of its own, which asks.
      if self.someoneIsOnItsWayOutOfFullScreen(on: display) || !self.knowsTheDisplays {
        guard turns < 40 else { return waiting.forEach(self.journeyIsOver) }
        return self.askAgain(on: display, after: 0.25, havingWaited: turns + 1)
      }
      // Counted here and not by the answers, so that it ends whatever the clock says and however many layouts come between.
      for window in waiting { self.journeys[window]?.askedAgain += 1 }
      for window in waiting {
        guard let owed = self.journeys[window]?.owed else { continue }
        // Only if it is still where that answer left it: whoever has moved or sized it since, a hand or its app, has had the last word.
        guard self.windows[window]?.frame == owed.has, !self.parked.contains(window),
          self.workspaces.values.contains(where: { $0.isFloating(window) })
        else {
          self.journeyIsOver(window)
          continue
        }
        _ = self.give(owed.wanted, to: window)
      }
      self.isAskingAgainAfterAJourney = true
      self.relayout(display, reason: .enforce)
      self.isAskingAgainAfterAJourney = false
      // Whoever that layout did not come to (out of view, given up on, held) is asked by the layout that does.
      if !self.displaysToAskAgain.contains(display) { self.journeys.filter { $0.value.display == display }.keys.sorted().forEach(self.journeyIsOver) }
    }
  }

  /// It has what it was asked for, has answered for itself, has gone, or is somebody else's business by now.
  func journeyIsOver(_ window: WindowID) {
    guard let journey = journeys.removeValue(forKey: window) else { return }
    guard displaysToAskAgain.contains(journey.display), !journeys.values.contains(where: { $0.display == journey.display }) else { return }
    displaysToAskAgain.remove(journey.display)
    scheduler.cancel(askAgainKey(journey.display))
  }
}
