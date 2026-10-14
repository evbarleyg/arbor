// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
import Foundation

@MainActor func probeServer(_ fd: Int32) {
  let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
  source.setEventHandler { MainActor.assumeIsolated {} }
  source.resume()
  source.start()  // wrong
  let files = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
  files.cancel()
  _ = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, events: .write)  // wrong
}
