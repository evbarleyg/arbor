// The dispatch sources that only Darwin has (scripts/typecheck-mac/README.md). Never shipped, never run.

public protocol DispatchSourceFileSystemObject: DispatchSourceProtocol {
  var handle: Int32 { get }
  var data: DispatchSource.FileSystemEvent { get }
  var mask: DispatchSource.FileSystemEvent { get }
}
public protocol DispatchSourceProcess: DispatchSourceProtocol {
  var handle: pid_t { get }
  var data: DispatchSource.ProcessEvent { get }
  var mask: DispatchSource.ProcessEvent { get }
}
public protocol DispatchSourceMemoryPressure: DispatchSourceProtocol {
  var data: DispatchSource.MemoryPressureEvent { get }
  var mask: DispatchSource.MemoryPressureEvent { get }
}
extension DispatchSource {
  // `FileSystemEvent` itself is there on Linux too.
  public struct ProcessEvent: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let exit = ProcessEvent(rawValue: 0x8000_0000)
    public static let fork = ProcessEvent(rawValue: 0x4000_0000)
    public static let exec = ProcessEvent(rawValue: 0x2000_0000)
    public static let signal = ProcessEvent(rawValue: 0x0800_0000)
    public static let all: ProcessEvent = [.exit, .fork, .exec, .signal]
  }
  public struct MemoryPressureEvent: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let normal = MemoryPressureEvent(rawValue: 0x1)
    public static let warning = MemoryPressureEvent(rawValue: 0x2)
    public static let critical = MemoryPressureEvent(rawValue: 0x4)
    public static let all: MemoryPressureEvent = [.normal, .warning, .critical]
  }
  public class func makeFileSystemObjectSource(fileDescriptor: Int32, eventMask: FileSystemEvent, queue: DispatchQueue? = nil)
    -> any DispatchSourceFileSystemObject
  { fatalError() }
  public class func makeProcessSource(identifier: pid_t, eventMask: ProcessEvent, queue: DispatchQueue? = nil) -> any DispatchSourceProcess {
    fatalError()
  }
  public class func makeMemoryPressureSource(eventMask: MemoryPressureEvent, queue: DispatchQueue? = nil) -> any DispatchSourceMemoryPressure {
    fatalError()
  }
}
