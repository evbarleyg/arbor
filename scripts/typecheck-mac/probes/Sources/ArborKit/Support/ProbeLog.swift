// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
import Foundation
import os

func probeLog(_ text: String) {
  let log = Logger(subsystem: "dev.arbor", category: "probe")
  log.info("\(text, privacy: .public)")
  // The unified log takes a literal only.
  log.info(text)  // wrong
  log.inform("x")  // wrong
}
