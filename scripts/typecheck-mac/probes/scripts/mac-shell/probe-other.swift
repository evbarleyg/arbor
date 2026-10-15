// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// One broken helper must not keep the others from being looked at.
import AppKit
import FakeMacOS  // wrong

_ = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
_ = CGWindowListCopyWindowInfo([.everything], kCGNullWindowID)  // wrong
