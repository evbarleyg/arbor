// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// What Linux's toolchain has whatever the version, and a Mac only from macOS 15 on (prepare.py's check). Arbor runs on 14.
import Foundation
import Synchronization  // wrong

func probeNewerThanMacOS14() {
  let wide: Int128 = 1  // wrong
  let ranges = RangeSet<Int>()  // wrong
  let evens = [1, 2, 3].indices(where: { $0 % 2 == 0 })  // wrong
  _ = (wide, ranges, evens)
  // These are old enough.
  _ = [1, 2, 3].firstIndex(where: { $0 % 2 == 0 })
  _ = Duration.seconds(1)
  _ = URL(filePath: "/tmp")
}
