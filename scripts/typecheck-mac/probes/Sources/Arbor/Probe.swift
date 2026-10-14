// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// One broken executable must not keep the others from being looked at.
import AppKit

@MainActor func probeArbor() {
  _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
  _ = CGWindowListCopyWindowInfo([.everything], kCGNullWindowID)  // wrong
  NSApplication.shared.begin()  // wrong
}
