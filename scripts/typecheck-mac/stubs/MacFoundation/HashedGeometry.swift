// CGRect and its kin can be hashed only from macOS 15, and Arbor runs on 14. Linux's always can, and a conformance cannot be taken away. So the
// ways into a set, a dictionary or a hasher get a twin here that is more specialised, which the compiler therefore prefers, and that is
// deprecated with the Mac's own words; check.sh makes an error of that warning. (Not `unavailable`: the compiler goes out of its way
// to avoid what is unavailable, and would pick the general one.) prepare.py sees the types where they are spelt out, `Set<CGRect>`.
import Foundation

public protocol _HashableFromMacOS15: Hashable {}
extension CGRect: _HashableFromMacOS15 {}
extension CGPoint: _HashableFromMacOS15 {}
extension CGSize: _HashableFromMacOS15 {}

extension Set where Element: _HashableFromMacOS15 {
  @available(*, deprecated, message: "conformance of geometry to 'Hashable' is only available in macOS 15.0 or newer")
  public init<Source: Sequence>(_ sequence: Source) where Source.Element == Element {
    self = []
    for element in sequence { _ = self.insert(element) }
  }
}
extension Dictionary where Key: _HashableFromMacOS15 {
  @available(*, deprecated, message: "conformance of geometry to 'Hashable' is only available in macOS 15.0 or newer")
  public init<S: Sequence>(uniqueKeysWithValues keysAndValues: S) where S.Element == (Key, Value) {
    self = [:]
    for (key, value) in keysAndValues { self[key] = value }
  }
  @available(*, deprecated, message: "conformance of geometry to 'Hashable' is only available in macOS 15.0 or newer")
  public init<S: Sequence>(_ keysAndValues: S, uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows where S.Element == (Key, Value) {
    self = [:]
    for (key, value) in keysAndValues { self[key] = try self[key].map { try combine($0, value) } ?? value }
  }
  @available(*, deprecated, message: "conformance of geometry to 'Hashable' is only available in macOS 15.0 or newer")
  public init<S: Sequence>(grouping values: S, by keyForValue: (S.Element) throws -> Key) rethrows where Value == [S.Element] {
    self = [:]
    for value in values { self[try keyForValue(value), default: []].append(value) }
  }
}
extension Hasher {
  @available(*, deprecated, message: "conformance of geometry to 'Hashable' is only available in macOS 15.0 or newer")
  public mutating func combine<H: _HashableFromMacOS15>(_ value: H) { value.hash(into: &self) }
}
