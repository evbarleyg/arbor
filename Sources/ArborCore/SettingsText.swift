import Foundation

/// Reading and rewriting the contents of `settings.json`. People edit that file by hand, so Arbor says
/// where a typo is, and when a command changes a setting it changes that setting in the text and
/// leaves the rest alone (`JSONText`).
extension Settings {
  /// Why `settings.json` could not be read or rewritten, in words for the person who edits it.
  public struct FileError: Error, Equatable, Sendable, CustomStringConvertible {
    public var description: String
    /// `description` without what it quotes from the file. A typo can sit in a rule's `title`, which is
    /// part of a window title, and titles are never logged.
    public var forTheLog: String

    public init(_ description: String, forTheLog: String? = nil) {
      self.description = description
      self.forTheLog = forTheLog ?? description
    }

    init(_ error: JSONText.SyntaxError) {
      self.init(error.description, forTheLog: "line \(error.line), column \(error.column)")
    }

    public static func == (a: FileError, b: FileError) -> Bool { a.description == b.description }
  }

  /// What in `settings.json` could not be used as written, for the log: which key and which entry, never why. The reasons quote the
  /// file ("`mauve` is not …"), and a wrong word where one of Arbor's own was wanted is still something a person typed; so is a number, and
  /// so is what stands for a rule's app. A log is what people paste into a public issue. `doctor` gives the reasons to whoever sits there.
  ///
  /// Made from what Arbor knows, not by taking words out of the reasons: a key is written only if it is one of the schema's.
  public var problemsForTheLog: [String] {
    let keys = valueProblems.map { problem in (try? SettingsSchema.entry(named: String(problem.prefix { $0 != ":" })))?.key ?? "a key" }
    // "entry 3 (com.apple.Notes): …", or a sentence about the whole list.
    let rules = skippedRules.map { reason in
      reason.hasPrefix("entry ") ? Int(reason.dropFirst(6).prefix(while: \.isNumber)).map { "entry \($0) of rules" } ?? "an entry of rules" : "rules"
    }
    // `doctor` does not list these; `displays` does.
    let displays = skippedDisplays.isEmpty || !skippedDisplayNumbers.isEmpty ? skippedDisplayNumbers.map { "entry \($0) of displays" } : ["displays"]
    return (keys + rules).map { "\($0) cannot be used as written; `doctor` says why" }
      + displays.map { "\($0) cannot be used as written; `displays` says why" }
  }

  // MARK: Reading

  /// Reads the contents of `settings.json`. Whatever `JSONDecoder` can read is read, as it always
  /// was. For the rest, throws a `FileError` that says where the problem is.
  public static func read(_ data: Data) throws -> Settings {
    do {
      return try JSONDecoder().decode(Settings.self, from: data)
    } catch {
      throw explain(data)
    }
  }

  public static func read(_ text: String) throws -> Settings { try read(Data(text.utf8)) }

  /// The text of a new `settings.json`: every key, so there is something to edit.
  public var fileText: String {
    get throws {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
    }
  }

  // MARK: Rewriting

  /// `text`, the contents of `settings.json`, with what changed between `old` and `new` written into
  /// it and every other byte as it was. So all of this survives:
  /// - keys Arbor does not know, and the file's order, spacing and spelling of numbers;
  /// - entries it could not read (skipped rules, bindings with a value of the wrong type);
  /// - edits made since the file was loaded, which `new` knows nothing about.
  ///
  /// It is a three-way merge: `old` is the base, `text` is theirs, `new` is ours. A key that is the
  /// same in `old` and `new` is not touched, whatever the file says: not even a value Arbor could not
  /// use (`valueProblems`), which stays for whoever wrote it to put right. Giving that key a value
  /// puts it right, even the value Arbor was using instead: `new` then no longer lists the problem.
  ///
  /// Within a changed key:
  /// - an object (`bindings`) is changed entry by entry;
  /// - a list of plain values (`excludedBundleIDs`) is a set: the file's list gains what was added and
  ///   loses what was removed, and keeps its order;
  /// - `rules` takes the order of `new`. A rule that did not change stays as written; one that changed in
  ///   its place is changed key by key; entries `old` does not know (unreadable, or added by hand) stay
  ///   in front of the rule they were in front of; and a rule deleted by hand stays deleted.
  ///
  /// Throws a `FileError`, and so changes nothing, if Arbor cannot read `text`: the typo that made it
  /// unreadable must not cost the rest of the file. The same goes for a change to a list or an object
  /// that Arbor could not use, unless the change empties it, which is what `reset` asks for. A single
  /// value it could not use is simply replaced.
  public static func rewrite(_ text: String, from old: Settings, to new: Settings) throws -> String {
    let file = try read(text)
    let current = try canonical(file)
    let unusable = file.valueProblems.map { $0.prefix { $0 != ":" } }
    let before = try canonical(old)
    let after = try canonical(new)
    var replaced: [String] = []
    let putRight = Set(old.valueProblems).subtracting(new.valueProblems).map { $0.prefix { $0 != ":" } }

    let document = try describingEditErrors {
      var document = try JSONText(text)
      for key in after.keys(at: []) ?? []
      where before.value(at: [key]) != after.value(at: [key]) || putRight.contains(key[...]) {
        // A key the file leaves out, or sets to null, is an empty list or object to merge into.
        let isMissing = document.value(at: [key]) ?? "null" == "null"
        if key == "rules" {
          guard let written = isMissing ? [] : document.elements(at: [key]) else {
            throw FileError("`rules` is not a list, so the rules cannot be saved; fix it first")
          }
          let merged = try mergedRules(written, from: old.rules, to: new.rules)
          if merged != written.map({ .verbatim($0) }) {
            document = try document.settingArray([key], to: merged)
          }
        } else if let was = before.elements(at: [key]), let now = after.elements(at: [key]) {
          // Reading forgives a value it cannot use. Writing over one could cost what somebody meant by it.
          guard !unusable.contains(key[...]), let written = isMissing ? [] : document.elements(at: [key]),
            let meanings = isMissing ? [] : current.elements(at: [key]), written.count == meanings.count
          else {
            guard now.isEmpty else {
              throw FileError("`\(key)` is not a list Arbor can read, so it cannot be changed; fix it first")
            }
            document = try document.setting([key], to: "[]")
            continue
          }
          var merged = zip(written, meanings).filter { now.contains($0.1) || !was.contains($0.1) }
            .map { JSONText.Element.verbatim($0.0) }
          merged += now.filter { !was.contains($0) && !meanings.contains($0) }.map { .value($0) }
          if merged != written.map({ .verbatim($0) }) {
            document = try document.settingArray([key], to: merged)
          }
        } else if before.keys(at: [key]) != nil, after.keys(at: [key]) != nil {
          guard !unusable.contains(key[...]), isMissing || document.keys(at: [key]) != nil else {
            guard after.keys(at: [key]) == [] else {
              throw FileError("`\(key)` is not an object Arbor can read, so it cannot be changed; fix it first")
            }
            document = try document.setting([key], to: "{}")
            continue
          }
          if document.value(at: [key]) == "null" { document = try document.setting([key], to: "{}") }
          document = try patching(document, at: [key], from: before, to: after)
        } else {
          document = try document.setting([key], to: after.value(at: [key])!)
          replaced.append(key)
        }
      }
      return document
    }

    // Never hand back text that would not read back as what was asked for.
    let result = try canonical(try read(document.text))
    for key in replaced where result.value(at: [key]) != after.value(at: [key]) {
      throw FileError("`\(key)` could not be written")
    }
    return document.text
  }

  /// `document` with what changed between the objects at `path` of `before` and `after`, entry by entry.
  private static func patching(
    _ document: JSONText, at path: [String], from before: JSONText, to after: JSONText
  ) throws -> JSONText {
    var document = document
    let now = after.keys(at: path) ?? []
    for entry in before.keys(at: path) ?? [] where !now.contains(entry) {
      document = try document.removing(path + [entry])
    }
    for entry in now where before.value(at: path + [entry]) != after.value(at: path + [entry]) {
      document = try document.setting(path + [entry], to: after.value(at: path + [entry])!)
    }
    return document
  }

  /// The `rules` list to write, given the entries the file has now (see `rewrite`).
  private static func mergedRules(
    _ written: [String], from old: [AppRule], to new: [AppRule]
  ) throws -> [JSONText.Element] {
    // Sort the file's entries into the rules Arbor loaded and everything else.
    var known: [(rule: AppRule, place: Int, text: String)] = []
    var foreign: [(knownBefore: Int, text: String)] = []
    var addedByHand: [AppRule] = []
    var missing = Array(old.enumerated())
    for text in written {
      let rule = try? JSONDecoder().decode(AppRule.self, from: Data(text.utf8))
      if let rule, let index = missing.firstIndex(where: { $0.element == rule }) {
        known.append((rule, missing.remove(at: index).offset, text))
      } else {
        foreign.append((known.count, text))
        if let rule { addedByHand.append(rule) }
      }
    }
    // What is left of `old` was deleted from the file by hand.
    var deleted = missing.map(\.element)

    // Which of the file's entries each new rule is written from. A rule that stays where it is among the
    // others is written from its own: of two that are the same, each keeps what was added to it by hand.
    // (Where it is in the file, not in `old`: saving the same change twice must not move anything.)
    var free = Set(known.indices)
    var sources = [Int?](repeating: nil, count: new.count)
    for (entry, place) in commonInOrder(known.map(\.rule), new) { sources[place] = free.remove(entry) }
    // Then the same rule from elsewhere in the list, which was moved. Or else the rule that was in its
    // place and is gone from the list, which it is then an edit of.
    for (place, rule) in new.enumerated() where sources[place] == nil {
      sources[place] = known.indices.first { free.contains($0) && known[$0].rule == rule }.map { free.remove($0)! }
    }
    var skipped = Set<Int>()
    for (place, rule) in new.enumerated() where sources[place] == nil {
      if let index = deleted.firstIndex(of: rule) {
        deleted.remove(at: index)
        skipped.insert(place)
      } else if let index = addedByHand.firstIndex(of: rule) {
        // The file has it already, so saving the same change twice does not add it twice.
        addedByHand.remove(at: index)
        skipped.insert(place)
      } else {
        sources[place] = free.first { known[$0].place == place }.map { free.remove($0)! }
      }
    }

    // An entry Arbor does not know stays in front of the next rule after it that is still there.
    let surviving = Set(sources.compactMap { $0 })
    func anchor(_ entry: (knownBefore: Int, text: String)) -> Int? {
      (entry.knownBefore..<known.count).first(where: surviving.contains)
    }
    var elements: [JSONText.Element] = []
    for (place, rule) in new.enumerated() where !skipped.contains(place) {
      guard let source = sources[place] else {
        elements.append(.value(try checked(try json(of: rule), is: rule, at: place)))
        continue
      }
      elements += foreign.filter { anchor($0) == source }.map { .verbatim($0.text) }
      var text = known[source].text
      if known[source].rule != rule {
        let edited = try patching(
          try JSONText(text), at: [], from: try canonical(known[source].rule), to: try canonical(rule))
        text = try checked(edited.text, is: rule, at: place)
      }
      elements.append(.verbatim(text))
    }
    return elements + foreign.filter { anchor($0) == nil }.map { .verbatim($0.text) }
  }

  /// The places, in `a` and in `b`, of the longest run of rules the two lists have in common, in order.
  private static func commonInOrder(_ a: [AppRule], _ b: [AppRule]) -> [(Int, Int)] {
    // A command changes one rule, so nearly everything is a common beginning or end.
    var start = 0
    while start < min(a.count, b.count), a[start] == b[start] { start += 1 }
    var (endA, endB) = (a.count, b.count)
    while endA > start, endB > start, a[endA - 1] == b[endB - 1] { (endA, endB) = (endA - 1, endB - 1) }
    var pairs = (0..<start).map { ($0, $0) }

    // Between them: lengths[i][j] is how much a[i...] and b[j...] have in common. Two long lists with nothing
    // in common at either end are not worth a table of millions; what follows copes without.
    let (rows, columns) = (endA - start, endB - start)
    if rows > 0, columns > 0, rows * columns <= 1_000_000 {
      var lengths = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
      for i in (0..<rows).reversed() {
        for j in (0..<columns).reversed() {
          lengths[i][j] =
            a[start + i] == b[start + j] ? lengths[i + 1][j + 1] + 1 : max(lengths[i + 1][j], lengths[i][j + 1])
        }
      }
      var (i, j) = (0, 0)
      while i < rows, j < columns {
        if a[start + i] == b[start + j] {
          pairs.append((start + i, start + j))
          (i, j) = (i + 1, j + 1)
        } else if lengths[i + 1][j] >= lengths[i][j + 1] {
          i += 1
        } else {
          j += 1
        }
      }
    }
    return pairs + (0..<(a.count - endA)).map { (endA + $0, endB + $0) }
  }

  /// A new rule as JSON, its keys in the order people write them rather than the alphabet's.
  private static func json(of rule: AppRule) throws -> String {
    let sorted = try canonical(rule)
    let keys = sorted.keys(at: []) ?? []
    let usual = ["app", "title", "action"]
    let members = (usual.filter(keys.contains) + keys.filter { !usual.contains($0) }).map {
      JSONText.quote($0) + ":" + sorted.value(at: [$0])!
    }
    return "{" + members.joined(separator: ",") + "}"
  }

  /// `text`, once it is sure that it reads back as `rule`. A rule that would not (an `app` with a space
  /// in it) would be skipped from then on, and no command could remove it.
  private static func checked(_ text: String, is rule: AppRule, at place: Int) throws -> String {
    do {
      guard try JSONDecoder().decode(AppRule.self, from: Data(text.utf8)) == rule else {
        throw FileError("rule \(place + 1) could not be written")
      }
      return text
    } catch let error as DecodingError {
      throw FileError("rule \(place + 1) cannot be saved: \(AppRule.reason(for: error))")
    }
  }

  // MARK: Helpers

  /// A value in one fixed form, so that two values are equal exactly when their text is.
  private static func canonical(_ value: some Encodable) throws -> JSONText {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    do {
      return try JSONText(String(decoding: try encoder.encode(value), as: UTF8.self))
    } catch is EncodingError {
      throw FileError("a number that is infinite or not a number cannot be saved")
    }
  }

  private static func describingEditErrors<T>(_ body: () throws -> T) throws -> T {
    do {
      return try body()
    } catch let error as JSONText.SyntaxError {
      throw FileError(error)
    } catch let error as JSONText.EditError {
      throw FileError(error.description)
    }
  }

  /// Why `JSONDecoder` could not read `data`. A single value never fails a file (`Settings.init(from:)`),
  /// so this is about the file as a whole: mostly, where the typo is.
  private static func explain(_ data: Data) -> FileError {
    guard let text = String(data: data, encoding: .utf8) else { return FileError("the file is not UTF-8 text") }
    do {
      guard try JSONText(text, strict: true).keys(at: []) != nil else {
        return FileError("the settings must be inside { and }")
      }
    } catch let error as JSONText.SyntaxError {
      return FileError(error)
    } catch {
      return FileError("\(error)")
    }
    // The text is JSON, or the strict parser would have objected. What is left is a number like 1e999
    // in a place where nothing catches it.
    return FileError("a number in it is too large or too small to read")
  }
}
