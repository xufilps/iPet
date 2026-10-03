// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetSpeechSettingsTests:XCTestCase {
    func testDefaultsAndSanitizingInvalidPreferences() {
        let normal=PetSpeechSettings()
        XCTAssertEqual(normal.fontFamily,"");XCTAssertEqual(normal.fontSize,15)
        XCTAssertEqual(normal.opacity,0.8);XCTAssertEqual(normal.revealInterval,0.15)
        XCTAssertEqual(normal.holdMultiplier,1);XCTAssertTrue(normal.automaticDialogue)
        let bad=PetSpeechSettings(fontFamily:"bad\nname",fontSize:.nan,opacity:.infinity,revealInterval:-3,holdMultiplier:10)
        XCTAssertEqual(bad.fontFamily,"");XCTAssertEqual(bad.fontSize,15)
        XCTAssertEqual(bad.opacity,0.8);XCTAssertEqual(bad.revealInterval,0.05)
        XCTAssertEqual(bad.holdMultiplier,3)
    }
    func testCustomSpeedAndHoldKeepEmojiAndCompletionOnce() {
        let settings=PetSpeechSettings(revealInterval:0.1,holdMultiplier:2)
        var p=PetSpeechPlayback(text:"👨‍👩‍👧‍👦你好！",settings:settings)
        XCTAssertEqual(p.holdDuration,12)
        XCTAssertFalse(p.advance(by:0.1));XCTAssertEqual(p.displayedText,"👨‍👩‍👧‍👦你")
        XCTAssertFalse(p.advance(by:0.1));XCTAssertEqual(p.displayedText,"👨‍👩‍👧‍👦你好！")
        XCTAssertTrue(p.advance(by:0.10001));XCTAssertEqual(p.phase,.holding)
        XCTAssertFalse(p.advance(by:1));XCTAssertEqual(p.phase,.holding)
    }
    func testSettingsAreCapturedByEachMessageAndDefaultTimingUnchanged() {
        var settings=PetSpeechSettings(revealInterval:0.1,holdMultiplier:2)
        var p=PetSpeechPlayback(text:"你好",settings:settings)
        settings=PetSpeechSettings(revealInterval:0.5,holdMultiplier:0.5)
        p.advance(by:0.1);XCTAssertEqual(p.displayedText,"你好")
        XCTAssertEqual(p.holdDuration,8)
        let other=PetSpeechPlayback(text:"你好",settings:settings)
        XCTAssertEqual(other.holdDuration,2)
        var normal=PetSpeechPlayback(text:"你好")
        normal.advance(by:0.15);XCTAssertEqual(normal.displayedText,"你好")
        XCTAssertEqual(normal.phase,.revealing);XCTAssertEqual(normal.holdDuration,4)
    }
    func testCustomTimingHoverAndCancellationCannotReplay() {
        var p=PetSpeechPlayback(text:"你好",settings:PetSpeechSettings(revealInterval:0.05,holdMultiplier:0.5))
        p.setHovered(true);XCTAssertTrue(p.advance(by:100))
        XCTAssertEqual(p.phase,.holding);XCTAssertFalse(p.advance(by:100))
        p.setHovered(false);p.advance(by:2.1);XCTAssertEqual(p.phase,.fading)
        p.cancel();p.setHovered(true);XCTAssertFalse(p.advance(by:100));XCTAssertEqual(p.phase,.finished)
    }
}
