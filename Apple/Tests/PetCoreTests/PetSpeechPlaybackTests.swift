import XCTest
@testable import PetCore

final class PetSpeechPlaybackTests:XCTestCase {
    func testRevealPairsThenWaitsForEmptyTickBeforeHolding() {
        var speech=PetSpeechPlayback(text:"你好世界")
        XCTAssertEqual(speech.displayedText,"");XCTAssertEqual(speech.phase,.revealing)
        speech.advance(by:0.15);XCTAssertEqual(speech.displayedText,"你好")
        speech.advance(by:0.15);XCTAssertEqual(speech.displayedText,"你好世界")
        XCTAssertEqual(speech.phase,.revealing)
        speech.advance(by:0.150001);XCTAssertEqual(speech.phase,.holding)
        XCTAssertEqual(speech.holdDuration,4)
    }
    func testPunctuationHoldAndDiscreteFadeMatchOriginal() {
        var speech=PetSpeechPlayback(text:"你好！")
        XCTAssertEqual(speech.holdDuration,6)
        speech.advance(by:0.450001+6);XCTAssertEqual(speech.phase,.fading)
        XCTAssertEqual(speech.opacity,0.8,accuracy:0.00001)
        speech.advance(by:0.05);XCTAssertEqual(speech.opacity,0.78,accuracy:0.00001)
        speech.advance(by:1.85);XCTAssertEqual(speech.opacity,0.04,accuracy:0.00001)
        XCTAssertEqual(speech.phase,.fading)
        speech.advance(by:0.05);XCTAssertEqual(speech.phase,.finished)
    }
    func testOriginalPunctuationNormalizesCRAndDoubleNewlines() {
        XCTAssertEqual(PetSpeechPlayback(text:"甲\r\n\n乙，。！？；：.,!?;:").holdDuration,30)
        XCTAssertEqual(PetSpeechPlayback(text:"没有标点").holdDuration,4)
    }
    func testGraphemeSafetyCancellationAndInvalidClockDeltas() {
        var speech=PetSpeechPlayback(text:"👨‍👩‍👧‍👦e\u{301}中文")
        speech.advance(by:0.15);XCTAssertEqual(speech.displayedText,"👨‍👩‍👧‍👦e\u{301}")
        for invalid in [-1.0,Double.nan,Double.infinity] { speech.advance(by:invalid) }
        XCTAssertEqual(speech.displayedText,"👨‍👩‍👧‍👦e\u{301}")
        speech.cancel();speech.advance(by:100);XCTAssertEqual(speech.phase,.finished)
        XCTAssertEqual(speech.displayedText,"")
    }
    func testLongTextBoundAndDeterministicElapsedTime() {
        let original=String(repeating:"字",count:4001)
        var speech=PetSpeechPlayback(text:original)
        XCTAssertTrue(speech.wasTruncated);XCTAssertEqual(speech.fullText.count,4000)
        speech.advance(by:0.3)
        var repeated=PetSpeechPlayback(text:original)
        repeated.advance(by:0.15);repeated.advance(by:0.15)
        XCTAssertEqual(speech.displayedText,repeated.displayedText)
        var empty=PetSpeechPlayback(text:"");empty.advance(by:0.15)
        XCTAssertEqual(empty.phase,.holding)
    }
    func testRevealCompletionSignalsOnceEvenWhenClockSkipsHolding() {
        var speech=PetSpeechPlayback(text:"你好")
        XCTAssertFalse(speech.advance(by:0.15))
        XCTAssertTrue(speech.advance(by:0.15))
        XCTAssertFalse(speech.advance(by:1))
        var skipped=PetSpeechPlayback(text:"你好")
        XCTAssertTrue(skipped.advance(by:100))
        XCTAssertFalse(skipped.advance(by:100))
        var cancelled=PetSpeechPlayback(text:"你好")
        cancelled.cancel();XCTAssertFalse(cancelled.advance(by:100))
    }

    func testHoveredRevealContinuesThenHoldingWaits() {
        var speech=PetSpeechPlayback(text:"你好世界")
        speech.setHovered(true);XCTAssertTrue(speech.advance(by:100))
        XCTAssertEqual(speech.displayedText,"你好世界");XCTAssertEqual(speech.phase,.holding)
        speech.advance(by:100);XCTAssertEqual(speech.phase,.holding)
        speech.setHovered(false);speech.advance(by:4.1);XCTAssertEqual(speech.phase,.fading)
    }
    func testHoverPreservesRemainingHoldAndRestartsFade() {
        var speech=PetSpeechPlayback(text:"你好")
        speech.advance(by:0.3+2);speech.setHovered(true);speech.advance(by:100)
        speech.setHovered(false);speech.advance(by:2.1);XCTAssertEqual(speech.phase,.fading)
        speech.advance(by:0.5);XCTAssertLessThan(speech.opacity,0.8)
        speech.setHovered(true);XCTAssertEqual(speech.opacity,0.8,accuracy:0.00001)
        speech.advance(by:100);XCTAssertEqual(speech.phase,.fading)
        speech.setHovered(false);speech.advance(by:1.95);XCTAssertEqual(speech.phase,.finished)
    }
    func testHoverCannotReviveCancelledOrFinishedText() {
        var cancelled=PetSpeechPlayback(text:"你好")
        cancelled.cancel();cancelled.setHovered(true);XCTAssertFalse(cancelled.advance(by:100))
        XCTAssertEqual(cancelled.phase,.finished)
        var ended=PetSpeechPlayback(text:"你好")
        ended.advance(by:100);ended.setHovered(true)
        XCTAssertEqual(ended.phase,.finished)
    }

}
