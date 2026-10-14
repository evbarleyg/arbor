extension KeyChord {
  /// The shortcut somebody has just pressed, to record it: the one that `code(in:)` takes back to that key on that
  /// layout, under the name people would give it. `KeyLayout`'s rules read backwards:
  ///
  /// 1. a key that is a position on every layout (Space, the arrows, F5) is itself;
  /// 2. a key of the digit row that types its digit with ⇧ is that digit, as the saved views' shortcuts have it: `4`, not `'`,
  ///    in France;
  /// 3. with ⇧, a key for a sign that types what ⇧ makes of a sign on a US keyboard is that sign: ⇧, types ? in France, so it
  ///    is `/`, which is where ⌃⌥⇧/ is registered there;
  /// 4. a key that types a letter, digit or sign Arbor has a name for is called that: the key left of X is `y` in Germany;
  ///    failing that, rule 3 holds for any key: ⇧ß types ?, so it is `/`;
  /// 5. a key the layout gives nothing of the kind is called what a US keyboard has there, which is where such a name falls
  ///    back to anyway (`[` for Ü), or, if the layout has that character elsewhere, `us:` and that name.
  ///
  /// Nil for a key no shortcut can use: the numeric keypad, keys only some keyboards have.
  public init?(code: UInt32, modifiers: Modifiers, layout: KeyLayout) {
    var candidates: [KeyChord] = []
    if let key = Key.allCases.first(where: { $0.character == nil && $0.code == code }) {
      candidates.append(KeyChord(modifiers, key))
    }
    let here = Key.allCases.first { $0.character != nil && $0.code == code }
    if let here, here.character?.isNumber == true, layout.character(at: code, shifted: true) == here.character {
      candidates.append(KeyChord(modifiers, here))
    }
    let plain = layout.character(at: code)
    var shiftedSign: KeyChord?
    if modifiers.contains(.shift), let typed = layout.character(at: code, shifted: true),
      let sign = KeyLayout.shiftedSigns.first(where: { $0.value == typed })?.key, let key = Key(rawValue: String(sign))
    {
      shiftedSign = KeyChord(modifiers, key)
    }
    if let shiftedSign, plain?.isLetter != true, plain?.isNumber != true { candidates.append(shiftedSign) }
    if let plain, let key = Key(rawValue: String(plain)) { candidates.append(KeyChord(modifiers, key)) }
    if let shiftedSign { candidates.append(shiftedSign) }
    if let here { candidates += [KeyChord(modifiers, here), KeyChord(modifiers, here, positional: true)] }
    guard let chord = candidates.first(where: { $0.code(in: layout) == code }) else { return nil }
    self = chord
  }
}
