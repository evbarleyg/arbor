import AppKit

// ArborTestWindows: opens plain, labelled windows for the end-to-end runner
// to arrange, without touching anyone's real windows.
//
//   ArborTestWindows --count 3 [--min-size 2:700x500] [--max-size 1:300x200] [--regular] [--extras]
//
// --regular makes it an ordinary app with a Dock icon, which ⌘Tab can switch to, and with menus: ⌘W closes the window that has the keyboard.
// --extras also opens windows Arbor must leave alone: a utility panel, and a sheet on the first window.
// SIGUSR1 brings the app to the front, as a click on its Dock icon would if it had one.
// SIGUSR2 opens one more window, as ⌘N would.
//
// Prints one JSON line to stdout: {"pid":123,"windows":[4501,4502,4503]}
// (window numbers are CGWindowIDs). Exits when stdin closes. Until then it takes commands on stdin
// that make the windows minimize, move, open tabs, hang and so on: see Commands.swift.

struct Options {
  var count = 3
  var minimumSizes: [Int: NSSize] = [:]
  var maximumSizes: [Int: NSSize] = [:]
  var regular = false
  var extras = false
}

func parseOptions() -> Options {
  var options = Options()
  var arguments = Array(CommandLine.arguments.dropFirst())
  while !arguments.isEmpty {
    let flag = arguments.removeFirst()
    switch flag {
    case "--count":
      if let value = arguments.first.flatMap(Int.init) { options.count = value }
      if !arguments.isEmpty { arguments.removeFirst() }
    case "--min-size", "--max-size":
      // index:WxH, 1-based
      if let value = arguments.first {
        let parts = value.split(separator: ":")
        let dims = parts.last?.lowercased().split(separator: "x").compactMap { Double($0) } ?? []
        if parts.count == 2, let index = Int(parts[0]), dims.count == 2 {
          let size = NSSize(width: dims[0], height: dims[1])
          if flag == "--min-size" { options.minimumSizes[index] = size } else { options.maximumSizes[index] = size }
        }
        arguments.removeFirst()
      }
    case "--regular":
      options.regular = true
    case "--extras":
      options.extras = true
    default:
      break
    }
  }
  return options
}

/// An ordinary app has menus, and ⌘W means something in it: a script can tell where the key went by what closed.
@MainActor
func mainMenu() -> NSMenu {
  let menu = NSMenu()
  // The first item is the app's own menu, whatever it is called.
  let app = NSMenuItem()
  app.submenu = NSMenu()
  let file = NSMenuItem()
  file.submenu = NSMenu(title: "File")
  file.submenu?.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
  menu.addItem(app)
  menu.addItem(file)
  return menu
}

@MainActor
func openWindows(_ options: Options) -> [NSWindow] {
  let colours: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemTeal]
  var windows: [NSWindow] = []
  for index in 1...max(options.count, 1) {
    let window = NSWindow(
      contentRect: NSRect(x: 120 + index * 50, y: 160 + index * 40, width: 480, height: 320),
      styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Arbor Test \(index)"
    window.isReleasedWhenClosed = false
    // So that the green button, and AXFullScreen, mean full screen whatever the app's activation policy.
    window.collectionBehavior = [.fullScreenPrimary]
    // Opaque, so that a screenshot shows which window is in front.
    window.backgroundColor = colours[(index - 1) % colours.count]
    let label = NSTextField(labelWithString: "Arbor Test \(index)")
    label.font = .systemFont(ofSize: 28, weight: .semibold)
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    window.contentView?.addSubview(label)
    if let content = window.contentView {
      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
      ])
    }
    if let minimum = options.minimumSizes[index] {
      window.minSize = minimum
    }
    if let maximum = options.maximumSizes[index] {
      window.maxSize = maximum
      window.setContentSize(NSSize(width: min(480, maximum.width), height: min(320, maximum.height - 32)))
    }
    window.orderFrontRegardless()
    windows.append(window)
  }
  return windows
}

@MainActor
func openExtras(on first: NSWindow) -> [NSWindow] {
  let panel = NSPanel(
    contentRect: NSRect(x: 20, y: 90, width: 160, height: 80), styleMask: [.titled, .utilityWindow],
    backing: .buffered, defer: false)
  panel.title = "Arbor Test Panel"
  panel.isReleasedWhenClosed = false
  // Panels hide while their app is in the background, which this one always is.
  panel.hidesOnDeactivate = false
  panel.orderFrontRegardless()
  let sheet = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 220, height: 90), styleMask: [.titled], backing: .buffered, defer: false)
  sheet.isReleasedWhenClosed = false
  first.beginSheet(sheet)
  return [panel, sheet]
}

/// Windows opened after the start, kept alive.
@MainActor
enum LaterWindows {
  static var all: [NSWindow] = []
}

MainActor.assumeIsolated {
  let application = NSApplication.shared
  let options = parseOptions()
  // Accessory: no Dock icon and no focus stealing.
  application.setActivationPolicy(options.regular ? .regular : .accessory)
  if options.regular { application.mainMenu = mainMenu() }
  let windows = openWindows(options)
  // Not reported below: the runner arranges only the standard windows.
  let extras = options.extras ? openExtras(on: windows[0]) : []
  let numbers = windows.map { String($0.windowNumber) }.joined(separator: ",")
  print("{\"pid\":\(getpid()),\"windows\":[\(numbers)]}")
  fflush(stdout)

  signal(SIGUSR1, SIG_IGN)
  let activation = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
  activation.setEventHandler {
    MainActor.assumeIsolated { NSApp.activate(ignoringOtherApps: true) }
  }
  activation.resume()
  signal(SIGUSR2, SIG_IGN)
  let opening = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
  opening.setEventHandler {
    MainActor.assumeIsolated {
      var one = Options()
      one.count = 1
      let windows = openWindows(one)
      windows.first?.makeKeyAndOrderFront(nil)
      LaterWindows.all += windows
    }
  }
  opening.resume()

  let commands = Commands(windows)
  FileHandle.standardInput.readabilityHandler = { handle in
    let data = handle.availableData
    if data.isEmpty { exit(0) }
    let text = String(decoding: data, as: UTF8.self)
    DispatchQueue.main.async {
      MainActor.assumeIsolated { commands.receive(text) }
    }
  }
  withExtendedLifetime((windows, extras, activation, opening)) { application.run() }
}
