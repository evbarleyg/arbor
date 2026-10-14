#if os(macOS)
  import Foundation
  import Testing

  /// `swift build` does not know the helper tools of the Mac shell scripts (scripts/mac-shell/*.swift, vdisplay.m). The scripts
  /// compile them when they run, which is rarely, and then with a person's pointer and keyboard at stake. So they are
  /// type-checked wherever the tests run on a Mac. Nothing is written, and nothing is started but the compilers.
  @Suite struct MacShellToolsTests {
    /// Found from this file's own path, as the traces are.
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("scripts/mac-shell")

    static let files: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    /// And the two that `make app` and `make uninstall` run as scripts.
    static let swiftTools = files.filter { $0.hasSuffix(".swift") } + ["../make-icon.swift", "../out-of-view.swift"]
    static let objectiveCTools = files.filter { $0.hasSuffix(".m") }

    /// What the compiler complains of, or nothing. It runs in the tools' folder, so its messages do not say where the checkout is.
    private func complaints(_ arguments: [String]) throws -> String {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
      process.arguments = arguments
      process.currentDirectoryURL = Self.folder
      let output = Pipe()
      process.standardInput = FileHandle.nullDevice
      process.standardOutput = output
      process.standardError = output
      try process.run()
      let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      process.waitUntilExit()
      return process.terminationStatus == 0 ? "" : "exit code \(process.terminationStatus)\n\(text)"
    }

    @Test func theToolsAreFound() {
      #expect(Self.swiftTools.contains("pointer.swift") && Self.swiftTools.contains("curtain.swift"))
      #expect(Self.objectiveCTools == ["vdisplay.m"])
    }

    @Test(arguments: swiftTools)
    func aSwiftToolTypeChecks(file: String) throws {
      // Language mode 5, as lib.sh compiles them: they are scripts, and strict concurrency has nothing to protect in them.
      #expect(try complaints(["swiftc", "-typecheck", "-swift-version", "5", file]) == "")
    }

    @Test(arguments: objectiveCTools)
    func anObjectiveCToolParses(file: String) throws {
      #expect(try complaints(["clang", "-fobjc-arc", "-fsyntax-only", file]) == "")
    }
  }
#endif
