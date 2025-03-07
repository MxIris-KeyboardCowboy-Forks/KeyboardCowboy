@testable import Keyboard_Cowboy
import XCTest

final class KeyboardShortcutTriggerTests: XCTestCase {
  func testCopy() {
    let subject = KeyboardShortcutTrigger(
      allowRepeat: false,
      passthrough: true,
      holdDuration: 1.0,
      shortcuts: [
      .init(key: "a", modifiers: [.leftCommand]),
      .init(key: "b", modifiers: [.rightOption]),
    ])
    let copy = subject.copy()

    XCTAssertEqual(subject.allowRepeat, copy.allowRepeat)
    XCTAssertEqual(subject.passthrough, copy.passthrough)
    XCTAssertEqual(subject.holdDuration, copy.holdDuration)

    XCTAssertNotEqual(subject.shortcuts[0].id, copy.shortcuts[0].id)
    XCTAssertEqual(subject.shortcuts[0].key, copy.shortcuts[0].key)
    XCTAssertEqual(subject.shortcuts[0].modifiers, copy.shortcuts[0].modifiers)

    XCTAssertEqual(subject.passthrough, copy.passthrough)
    XCTAssertNotEqual(subject.shortcuts[1].id, copy.shortcuts[1].id)
    XCTAssertEqual(subject.shortcuts[1].key, copy.shortcuts[1].key)
    XCTAssertEqual(subject.shortcuts[1].modifiers, copy.shortcuts[1].modifiers)
  }
}
