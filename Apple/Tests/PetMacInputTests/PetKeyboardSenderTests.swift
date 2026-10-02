// SPDX-License-Identifier: Apache-2.0
#if os(macOS)
import XCTest
import CoreGraphics
import AppKit
import PetCore
@testable import PetMacInput
final class PetKeyboardSenderTests:XCTestCase {
    @MainActor func testLocalRecorderKeepsPhysicalKeyAndModifierOrder() throws {
        let event=try XCTUnwrap(NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[.command,.shift,.option],timestamp:0,windowNumber:0,context:nil,characters:"C",charactersIgnoringModifiers:"c",isARepeat:false,keyCode:8))
        let chord=try PetKeyRecording.chord(event)
        XCTAssertEqual(chord.keyCode,8);XCTAssertEqual(chord.modifiers,[.command,.option,.shift]);XCTAssertEqual(chord.label,"C")
        let enter=try XCTUnwrap(NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,characters:"\r",charactersIgnoringModifiers:"\r",isARepeat:false,keyCode:36))
        XCTAssertEqual(try PetKeyRecording.chord(enter).label,"Return")
    }
    @MainActor func testFocusNotificationCancelsEvenIfOriginalTargetReturns() async throws {
        var pid:Int32?=42,posts=0
        let sender=PetKeyboardSender(ownPID:100,permission:{true},frontmostPID:{pid},alive:{_ in true},post:{_,target in XCTAssertEqual(target,42);posts+=1},delayNanoseconds:1)
        XCTAssertTrue(sender.start(PetKeyboardMacro(steps:[.text("a")]),name:"test"))
        pid=43;sender.frontmostApplicationChanged();pid=42
        while sender.busy { await Task.yield() }
        XCTAssertEqual(posts,0)
    }
    @MainActor func testEventPairCarriesKeyFlagsAndUnicodeWithoutPosting() throws {
        let chord=PetKeyChord(keyCode:8,modifiers:[.command,.shift],label:"C")
        let pair=try PetKeyboardEventPair.make(.key(chord))
        XCTAssertEqual(pair.down.type,.keyDown);XCTAssertEqual(pair.up.type,.keyUp)
        XCTAssertEqual(pair.down.getIntegerValueField(.keyboardEventKeycode),8)
        XCTAssertTrue(pair.down.flags.contains([.maskCommand,.maskShift]))
        XCTAssertTrue(pair.up.flags.contains([.maskCommand,.maskShift]))
        let text=try PetKeyboardEventPair.make(.text("中文🙂"))
        var count=0;var buffer=[UniChar](repeating:0,count:20)
        text.down.keyboardGetUnicodeString(maxStringLength:20,actualStringLength:&count,unicodeString:&buffer)
        XCTAssertEqual(String(utf16CodeUnits:buffer,count:count),"中文🙂")
        XCTAssertThrowsError(try PetKeyboardEventPair.make(.text(String(repeating:"x",count:21))))
    }
    @MainActor func testSenderRefusesSelfMissingPermissionAndBusy() async throws {
        var permission=false,pid:Int32?=42,posts=0
        let sender=PetKeyboardSender(ownPID:100,permission:{permission},frontmostPID:{pid},alive:{_ in true},post:{_,_ in posts+=1},delayNanoseconds:1)
        let macro=PetKeyboardMacro(steps:[.text("a")])
        XCTAssertFalse(sender.start(macro,name:"test"));permission=true;pid=100
        XCTAssertFalse(sender.start(macro,name:"test"));pid=42
        XCTAssertTrue(sender.start(macro,name:"test"));XCTAssertFalse(sender.start(macro,name:"second"))
        while sender.busy { await Task.yield() }
        XCTAssertEqual(posts,1)
    }
    @MainActor func testFocusChangeStopsRemainingPairsAndExplicitCancel() async throws {
        var pid:Int32?=42,posts=0
        let sender=PetKeyboardSender(ownPID:100,permission:{true},frontmostPID:{pid},alive:{_ in true},post:{_,_ in posts+=1;pid=43},delayNanoseconds:1)
        XCTAssertTrue(sender.start(PetKeyboardMacro(steps:[.text("a"),.text("b")]),name:"test"))
        while sender.busy { await Task.yield() }
        XCTAssertEqual(posts,1);XCTAssertTrue(sender.status.contains("取消"))
        pid=42;posts=0
        XCTAssertTrue(sender.start(PetKeyboardMacro(steps:[.text("a")]),name:"test"));sender.cancel()
        while sender.busy { await Task.yield() }
        XCTAssertEqual(posts,0)
    }
    @MainActor func testDeadTargetAndRevokedPermissionStopBeforePosting() async throws {
        var alive=true,permission=true,posts=0
        let sender=PetKeyboardSender(ownPID:100,permission:{permission},frontmostPID:{42},alive:{_ in alive},post:{_,_ in posts+=1},delayNanoseconds:1)
        let macro=PetKeyboardMacro(steps:[.text("a")])
        XCTAssertTrue(sender.start(macro,name:"test"));alive=false
        while sender.busy { await Task.yield() }
        XCTAssertEqual(posts,0);alive=true
        XCTAssertTrue(sender.start(macro,name:"test"));permission=false
        while sender.busy { await Task.yield() }
        XCTAssertEqual(posts,0)
    }
}
#endif
