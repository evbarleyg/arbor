import Foundation

extension Runner {
  /// The end of Arbor's log, for a report that other people read. At its start Arbor logs what it found amiss on the Mac (`setup: Other window
  /// managers: …`, the Desktop & Dock switches): that is the person's own business, and so is where their temporary folders are.
  func forOthersToRead(_ log: String) -> String {
    log.split(separator: "\n").suffix(100).map { line -> String in
      var line = String(line).replacingOccurrences(of: "/private" + home.path, with: "<home>").replacingOccurrences(of: home.path, with: "<home>")
      if let heading = line.range(of: " setup: "), let colon = line[heading.upperBound...].firstIndex(of: ":") {
        line = line[..<colon] + ": (stays on this Mac)"
      }
      return line
    }.joined(separator: "\n")
  }
}
