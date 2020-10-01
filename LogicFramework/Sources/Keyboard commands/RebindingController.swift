import Carbon
import Cocoa

/// A rebinding controller is responsible for intercepting keyboard shortcuts and posting
/// alternate events when rebounded keys are invoked.
public protocol RebindingControlling {
  init() throws
  var isEnabled: Bool { get set }
  func monitor(_ workflows: [Workflow])
  func callback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ cgEvent: CGEvent) -> Unmanaged<CGEvent>?
}

enum RebindingControllingError: Error {
  case unableToCreateMachPort
  case unableToCreateRunLoopSource
  case unableToCreateEventSource
}

final class RebindingController: RebindingControlling {
  static var workflows = [Workflow]()
  private static var cache = [String: Int]()
  private var eventSource: CGEventSource!
  private var machPort: CFMachPort!
  private var runLoopSource: CFRunLoopSource!

  var isEnabled: Bool {
    set { machPort.map { CGEvent.tapEnable(tap: $0, enable: newValue) } }
    get { machPort.map(CGEvent.tapIsEnabled) ?? false }
  }

  required init() throws {
    self.eventSource = try createEventSource()
    self.machPort = try createMachPort()
    self.runLoopSource = try createRunLoopSource()
    Self.cache = KeyCodeMapper().hashTable()
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
  }

  func monitor(_ workflows: [Workflow]) {
    Self.workflows = workflows
  }

  func callback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let workflows = Self.workflows
    var result: Unmanaged<CGEvent>? = Unmanaged.passUnretained(event)

    for workflow in workflows {
      guard let keyboardShortcut = workflow.keyboardShortcuts.last,
            let shortcutKeyCode = Self.cache[keyboardShortcut.key.uppercased()] else { continue }

      guard keyCode == shortcutKeyCode else { continue }

      var modifiersMatch: Bool = true

      if let modifiers = keyboardShortcut.modifiers {
        modifiersMatch = eventFlagsMatchModifiers(event.flags, modifiers: modifiers)
      } else {
        modifiersMatch = event.flags.isDisjoint(with: [
          .maskControl, .maskCommand, .maskAlternate, .maskShift
        ])
      }

      guard modifiersMatch else { continue }

      for case .keyboard(let shortcut) in workflow.commands {
        guard let shortcutKeyCode = Self.cache[shortcut.keyboardShortcut.key.uppercased()] else {
          continue
        }
        if let cgKeyCode = CGKeyCode(exactly: shortcutKeyCode),
           let newEvent = CGEvent(keyboardEventSource: self.eventSource,
                                  virtualKey: cgKeyCode,
                                  keyDown: type == .keyDown) {
          newEvent.post(tap: .cghidEventTap)

          result = nil
        }
      }
    }

    return result
  }

  // MARK: Private methods

  private func createMachPort() throws -> CFMachPort? {
    let tap: CGEventTapLocation = .cgSessionEventTap
    let place: CGEventTapPlacement = .headInsertEventTap
    let options: CGEventTapOptions = .defaultTap
    let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
      | 1 << CGEventType.keyUp.rawValue
    guard let machPort = CGEvent.tapCreate(
            tap: tap,
            place: place,
            options: options,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
              if let pointer = userInfo {
                let controller = Unmanaged<RebindingController>.fromOpaque(pointer).takeUnretainedValue()
                return controller.callback(proxy, type, event)
              }
              return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())) else {
      throw RebindingControllingError.unableToCreateMachPort
    }
    return machPort
  }

  private func createRunLoopSource() throws -> CFRunLoopSource {
    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0) else {
      throw RebindingControllingError.unableToCreateRunLoopSource
    }
    return runLoopSource
  }

  private func createEventSource() throws -> CGEventSource {
    guard let eventSource = CGEventSource(stateID: .privateState) else {
      throw RebindingControllingError.unableToCreateEventSource
    }
    return eventSource
  }

  private func eventFlagsMatchModifiers(_ flags: CGEventFlags, modifiers: [ModifierKey]) -> Bool {
    var collectedModifiers = Set<ModifierKey>()

    if flags.contains(.maskShift) { collectedModifiers.insert(.shift) }

    if flags.contains(.maskControl) { collectedModifiers.insert(.control) }

    if flags.contains(.maskAlternate) { collectedModifiers.insert(.option) }

    if flags.contains(.maskCommand) { collectedModifiers.insert(.command) }

    if flags.contains(.maskSecondaryFn) { collectedModifiers.insert(.function) }

    let modifierSet = Set<ModifierKey>(modifiers)
    return collectedModifiers == modifierSet
  }
}