// menukeys: every shortcut in an app's menu bar, as Accessibility tells it, for Mac shell scripts.
//
//   menukeys <pid> [--titles]     one line per menu item that has a shortcut, tab-separated:
//                                 modifiers  character (hex scalars, or -)  virtual key (or -)  glyph (or -)  enabled  [title]
//                                 and a last line `read <items> items in <ms> ms, <n> with a shortcut`
//
// The numbers are raw, as macOS gives them (AXMenuItemCmdModifiers, AXMenuItemCmdChar, AXMenuItemCmdVirtualKey, AXMenuItemCmdGlyph), so that what
// they mean is worked out on Linux and under test (ArborTesting's MenuShortcut), and need not be asked of a Mac again.
//
// A title can hold a person's words (a document, a conversation, a bookmark). So titles are printed only when asked for, and only on one of
// GitHub's Macs, where every title is the app's own. Arbor itself reads no other app's menu bar at all.
//
// scripts/mac-shell/census-menu-keys.sh compiles it (swiftc -O -swift-version 5) and shows how it is used.

import ApplicationServices
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())
guard let pid = arguments.first.flatMap({ pid_t($0) }) else {
  FileHandle.standardError.write(Data("usage: menukeys <pid> [--titles]\n".utf8))
  exit(64)
}
let withTitles =
  arguments.contains("--titles") && ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true" && NSUserName() == "runner"

func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func children(_ element: AXUIElement) -> [AXUIElement] { value(element, "AXChildren") as? [AXUIElement] ?? [] }

var items = 0
var found = 0

func walk(_ element: AXUIElement, depth: Int) {
  // Deeper than any menu goes: an app that answers with a loop must not keep this for ever.
  guard depth < 8 else { return }
  for child in children(element) {
    items += 1
    let character = value(child, "AXMenuItemCmdChar") as? String ?? ""
    let key = value(child, "AXMenuItemCmdVirtualKey") as? Int
    let glyph = value(child, "AXMenuItemCmdGlyph") as? Int
    if !character.isEmpty || key != nil || glyph != nil {
      found += 1
      var fields = [
        String(value(child, "AXMenuItemCmdModifiers") as? Int ?? -1),
        character.isEmpty ? "-" : character.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: ","),
        key.map(String.init) ?? "-", glyph.map(String.init) ?? "-",
        (value(child, "AXEnabled") as? Bool).map { $0 ? "enabled" : "disabled" } ?? "-",
      ]
      if withTitles { fields.append((value(child, "AXTitle") as? String ?? "").replacingOccurrences(of: "\t", with: " ")) }
      print(fields.joined(separator: "\t"))
    }
    walk(child, depth: depth + 1)
  }
}

let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 2)
let began = DispatchTime.now().uptimeNanoseconds
guard let bar = value(app, "AXMenuBar"), CFGetTypeID(bar) == AXUIElementGetTypeID() else {
  print("no menu bar")
  exit(1)
}
walk(bar as! AXUIElement, depth: 0)
print("read \(items) items in \((DispatchTime.now().uptimeNanoseconds - began) / 1_000_000) ms, \(found) with a shortcut")
