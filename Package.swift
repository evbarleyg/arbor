// swift-tools-version: 6.0
import PackageDescription

// AppKit, Accessibility and Carbon exist only on macOS. Everything above the platform protocols
// (the core, the controller, the fakes, arbor-sim and the test targets) needs only Foundation and
// CoreGraphics' geometry types, and the control socket (its server, its client and arborctl) needs only
// POSIX and Dispatch, so all of it also builds on Linux, where CI and agents without a Mac run
// it. There the manifest leaves out the folders that hold the real implementations and the
// targets that cannot build at all, and adds a stand-in for CoreGraphics (Sources/LinuxShims).
#if os(macOS)
  let macOnlyKitFolders: [String] = []
  let macOnlyProducts: [Product] = [
    .executable(name: "Arbor", targets: ["Arbor"])
  ]
  let platformTargets: [Target] = [
    .executableTarget(name: "Arbor", dependencies: ["ArborKit"]),
    .executableTarget(name: "ArborTestWindows"),
    .executableTarget(name: "arbor-e2e", dependencies: ["ArborCore", "ArborIPC"]),
  ]
  let geometry: [Target.Dependency] = []
  // No Mac's compiler has seen arbor-fakemac yet, and a Mac has real windows to try things on: there it is built
  // only on request, so that it cannot break the build of the app.
  let withFakeMac = Context.environment["ARBOR_FAKEMAC"] != nil
#else
  let macOnlyKitFolders = ["AX", "App", "Input", "UI"]
  let macOnlyProducts: [Product] = []
  let platformTargets: [Target] = [
    .target(name: "CoreGraphics", path: "Sources/LinuxShims/CoreGraphics")
  ]
  let geometry: [Target.Dependency] = ["CoreGraphics"]
  let withFakeMac = true
#endif

// A Mac made of fakes, for rehearsing Mac shell scripts without one (scripts/mac-shell/rehearse.sh).
let fakeMac: [Target] = withFakeMac
  ? [.executableTarget(name: "arbor-fakemac", dependencies: ["ArborTesting", "ArborKit", "ArborCore"] + geometry)] : []

let package = Package(
  name: "Arbor",
  platforms: [.macOS(.v14)],
  products: macOnlyProducts + [
    .executable(name: "arborctl", targets: ["arborctl"]),
    .executable(name: "arbor-sim", targets: ["arbor-sim"]),
  ],
  targets: platformTargets + fakeMac + [
    // Pure model: layout tree, layout engine, navigation, drop targets,
    // commands, settings. No AppKit, no Accessibility, no side effects.
    .target(name: "ArborCore", dependencies: geometry),

    // Socket paths, the control protocol's framing, and the control-socket client shared by the
    // app, the CLI and the end-to-end runner.
    .target(name: "ArborIPC"),

    // The window manager: controller, platform protocols, the real
    // Accessibility/AppKit implementations, menus, hotkeys, control server.
    .target(name: "ArborKit", dependencies: ["ArborCore", "ArborIPC"] + geometry, exclude: macOnlyKitFolders),

    // In-memory fakes for the platform protocols. Used by tests and arbor-sim.
    .target(name: "ArborTesting", dependencies: ["ArborKit", "ArborCore"] + geometry),

    .executableTarget(name: "arbor-sim", dependencies: ["ArborTesting", "ArborKit", "ArborCore"] + geometry),

    .executableTarget(name: "arborctl", dependencies: ["ArborCore", "ArborIPC"]),

    .testTarget(name: "ArborCoreTests", dependencies: ["ArborCore"] + geometry),
    .testTarget(name: "ArborIPCTests", dependencies: ["ArborIPC"]),
    .testTarget(
      name: "ArborKitTests", dependencies: ["ArborKit", "ArborCore", "ArborIPC", "ArborTesting"] + geometry),
  ]
)
