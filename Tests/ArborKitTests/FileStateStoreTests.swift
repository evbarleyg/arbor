import ArborCore
import ArborKit
import CoreGraphics
import Foundation
import Testing

/// Saving happens off the main thread; what counts is that nothing is lost or reordered.
@Suite @MainActor struct FileStateStoreTests {
  func temporaryFile() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("arbor-state-\(UUID().uuidString).json")
  }

  func state(floating count: Int) -> PersistedState {
    var workspace = Workspace()
    for index in 0..<count { workspace.floating[WindowID(UInt32(100 + index))] = CGRect(x: index, y: 0, width: 10, height: 10) }
    return PersistedState(workspaces: [DisplayID("main"): workspace], hints: [:])
  }

  @Test func theLastOfManySavesIsWhatIsOnDiskAfterAFlush() throws {
    let url = temporaryFile()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileStateStore(url: url)
    for count in 1...40 { store.save(state(floating: count)) }
    store.flush()
    let data = try Data(contentsOf: url)
    #expect(try JSONDecoder().decode(PersistedState.self, from: data) == state(floating: 40))
  }

  @Test func whatWasFlushedCanBeLoaded() {
    let url = temporaryFile()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileStateStore(url: url)
    #expect(store.load() == nil)
    store.save(state(floating: 3))
    store.flush()
    #expect(FileStateStore(url: url).load() == state(floating: 3))
  }

  @Test func loadingSeesWhatWasJustSaved() {
    let url = temporaryFile()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileStateStore(url: url)
    store.save(state(floating: 5))
    #expect(store.load() == state(floating: 5))
  }
}
