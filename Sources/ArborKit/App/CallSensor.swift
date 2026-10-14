import ArborCore
import CoreAudio
import CoreMediaIO
import Foundation

/// Reads whether any app has a camera or a microphone running, for `Controller.callSignalsChanged` (F58). macOS tells
/// every process that much, without asking the user, because nothing is captured: Arbor opens no device.
///
/// It listens for the changes, and looks for itself twice a minute in case a listener was lost. All of it happens on
/// a queue of its own: these calls go to the audio and camera daemons, and one that is slow to answer must not
/// hold up the thread that moves people's windows. It decides nothing.
@MainActor
final class CallSensor {
  private let watch: Watch
  private var timer: (any DispatchSourceTimer)?

  init(onChange: @escaping @MainActor (CallSignals) -> Void) {
    watch = Watch(onChange: onChange)
  }

  /// Watches what the settings ask for. With neither, both are reported as off and nothing wakes up.
  func update(camera: Bool, microphone: Bool) {
    let watch = self.watch
    watch.queue.async {
      watch.camera = camera
      watch.microphone = microphone
      watch.look()
    }
    guard camera || microphone else { return stop() }
    guard timer == nil else { return }
    let timer = DispatchSource.makeTimerSource(queue: watch.queue)
    timer.schedule(deadline: .now() + .seconds(30), repeating: .seconds(30), leeway: .seconds(10))
    timer.setEventHandler { watch.look() }
    timer.resume()
    self.timer = timer
  }

  func stop() {
    timer?.cancel()
    timer = nil
  }
}

/// Everything but `queue` and `onChange` is touched only on `queue`.
private final class Watch: @unchecked Sendable {
  let queue = DispatchQueue(label: "arbor.call-sensor", qos: .utility)
  private let onChange: @MainActor (CallSignals) -> Void
  var camera = false
  var microphone = false
  private var last = CallSignals()
  /// What has a listener already. Listeners are never removed: a device that goes away takes its own along, and
  /// with both switches off `look()` finds nothing new to report.
  private var heardCameras = Set<CMIOObjectID>()
  private var heardAudioDevices = Set<AudioObjectID>()

  init(onChange: @escaping @MainActor (CallSignals) -> Void) {
    self.onChange = onChange
  }

  func look() {
    let signals = CallSignals(
      cameraIsOn: camera && aCameraIsRunning(), microphoneIsOn: microphone && aMicrophoneIsRunning())
    guard signals != last else { return }
    last = signals
    let onChange = self.onChange
    DispatchQueue.main.async { onChange(signals) }
  }

  // MARK: Cameras (CoreMediaIO)

  private func cameraAddress(_ selector: some BinaryInteger) -> CMIOObjectPropertyAddress {
    CMIOObjectPropertyAddress(
      mSelector: CMIOObjectPropertySelector(selector), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
  }

  private func listen(toCamera object: CMIOObjectID, _ selector: some BinaryInteger) {
    guard heardCameras.insert(object).inserted else { return }
    var address = cameraAddress(selector)
    _ = CMIOObjectAddPropertyListenerBlock(object, &address, queue) { [weak self] _, _ in self?.look() }
  }

  private func aCameraIsRunning() -> Bool {
    let system = CMIOObjectID(kCMIOObjectSystemObject)
    // Cameras come and go: a phone as a camera, a display with one.
    listen(toCamera: system, kCMIOHardwarePropertyDevices)
    var address = cameraAddress(kCMIOHardwarePropertyDevices)
    var size: UInt32 = 0
    guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
    var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
    var used: UInt32 = 0
    guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return false }
    address = cameraAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
    var found = false
    for device in devices {
      listen(toCamera: device, kCMIODevicePropertyDeviceIsRunningSomewhere)
      var running: UInt32 = 0
      let status = CMIOObjectGetPropertyData(
        device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &running)
      if status == noErr, running != 0 { found = true }
    }
    return found
  }

  // MARK: Microphones (CoreAudio)

  private func audioAddress(
    _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
  }

  private func listen(toAudio object: AudioObjectID, _ selector: AudioObjectPropertySelector) {
    guard heardAudioDevices.insert(object).inserted else { return }
    var address = audioAddress(selector)
    _ = AudioObjectAddPropertyListenerBlock(object, &address, queue) { [weak self] _, _ in self?.look() }
  }

  private func hasStreams(_ device: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Bool {
    var address = audioAddress(kAudioDevicePropertyStreams, scope)
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
  }

  private func aMicrophoneIsRunning() -> Bool {
    let system = AudioObjectID(kAudioObjectSystemObject)
    listen(toAudio: system, kAudioHardwarePropertyDevices)
    var address = audioAddress(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
    var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return false }
    address = audioAddress(kAudioDevicePropertyDeviceIsRunningSomewhere)
    var found = false
    for device in devices {
      // "Running" is said of a device, not of a direction. A headset that is one device for both is running while
      // it plays music, so only what is a microphone and nothing else is believed.
      guard hasStreams(device, kAudioObjectPropertyScopeInput), !hasStreams(device, kAudioObjectPropertyScopeOutput) else {
        continue
      }
      listen(toAudio: device, kAudioDevicePropertyDeviceIsRunningSomewhere)
      var running: UInt32 = 0
      var runningSize = UInt32(MemoryLayout<UInt32>.size)
      if AudioObjectGetPropertyData(device, &address, 0, nil, &runningSize, &running) == noErr, running != 0 { found = true }
    }
    return found
  }
}
