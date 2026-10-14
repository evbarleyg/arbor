import Foundation

/// Notices when settings.json may have changed, so that an edit applies without `reload-settings`.
///
/// It only says that something happened. Waiting for the editor to finish, and deciding whether the
/// file now says anything new, is `Controller.settingsFileMayHaveChanged()`, which tests can reach.
///
/// Two things are watched, because editors save in two ways. Most write a new file and move it over
/// the old one, which changes the folder; a watch on the file alone would be left holding the old
/// one, which nobody can see any more. Others (VS Code, nano, `echo >`) write into the file where it
/// is, which does not change the folder. So after every event the file at the path is opened again.
@MainActor
final class SettingsWatcher {
  private let file: URL
  private let onChange: @MainActor () -> Void
  private var folderSource: DispatchSourceFileSystemObject?
  private var fileSource: DispatchSourceFileSystemObject?

  init(file: URL, onChange: @escaping @MainActor () -> Void) {
    self.file = file
    self.onChange = onChange
  }

  func start() {
    stop()
    folderSource = watch(file.deletingLastPathComponent().path, for: .write)
    watchFile()
    if folderSource == nil {
      Log.error("cannot watch the folder of settings.json; run reload-settings after editing the file")
    }
  }

  func stop() {
    folderSource?.cancel()
    folderSource = nil
    fileSource?.cancel()
    fileSource = nil
  }

  private func changed() {
    watchFile()
    onChange()
  }

  /// Watches whatever is at the file's path now. Being deleted or renamed counts as well: if settings.json
  /// is a link into another folder, that is all there is to see of the file it points to being replaced.
  private func watchFile() {
    fileSource?.cancel()
    fileSource = watch(file.path, for: [.write, .extend, .delete, .rename])
  }

  /// Nil if there is nothing at `path`.
  private func watch(
    _ path: String, for events: DispatchSource.FileSystemEvent
  ) -> DispatchSourceFileSystemObject? {
    let descriptor = open(path, O_EVTONLY)
    guard descriptor >= 0 else { return nil }
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: events, queue: .main)
    source.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.changed() }
    }
    source.setCancelHandler { close(descriptor) }
    source.resume()
    return source
  }
}
