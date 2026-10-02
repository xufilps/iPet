// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetKeyboardMacroTests:XCTestCase {
    private let copy=PetKeyChord(keyCode:8,modifiers:[.command],label:"C")
    func testOrderedChordAndTextEmissionsRemainSeparate() throws {
        let macro=PetKeyboardMacro(steps:[.key(copy),.text("中文🙂"),.key(PetKeyChord(keyCode:36,modifiers:[],label:"Return"))])
        let emissions=try macro.emissions()
        XCTAssertEqual(emissions,[.key(copy),.text("中文🙂"),.key(PetKeyChord(keyCode:36,modifiers:[],label:"Return"))])
        XCTAssertEqual(try PetKeyboardMacro.decodeTarget(macro.encodedTarget()),macro)
    }
    func testUnicodeChunkingDoesNotSplitSurrogatePairs() throws {
        let input=String(repeating:"A",count:19)+"🙂"+String(repeating:"中",count:25)
        let chunks=try PetKeyboardMacro(steps:[.text(input)]).emissions().compactMap { step -> String? in if case .text(let text)=step { return text };return nil }
        XCTAssertEqual(chunks.joined(),input);XCTAssertEqual(chunks.first,String(repeating:"A",count:19))
        XCTAssertTrue(chunks.allSatisfy { $0.utf16.count<=20 && !$0.contains("�") })
    }
    func testJoinedEmojiAndCombiningMarksRemainValidThroughShortcutCodec() throws {
        let input=String(repeating:"👨‍👩‍👧‍👦e\u{301}",count:10)
        let macro=PetKeyboardMacro(steps:[.text(input)])
        let text=try macro.emissions().compactMap { step -> String? in if case .text(let value)=step { return value };return nil }.joined()
        XCTAssertEqual(Array(text.unicodeScalars),Array(input.unicodeScalars))
        XCTAssertNoThrow(try PetKeyChord(keyCode:8,modifiers:[],label:"👨‍👩‍👧‍👦").validate())
        let target=try macro.encodedTarget()
        XCTAssertNoThrow(try PetShortcutEntry(id:1,name:"文本",kind:.macKeys,target:target).validate())
    }
    func testCRLFTabsAndNewlinesUseNativeKeysInOrder() throws {
        let emitted=try PetKeyboardMacro(steps:[.text("a\r\n\tb\nc\rd")]).emissions()
        let keys=emitted.compactMap { step -> Int? in if case .key(let chord)=step { return chord.keyCode };return nil }
        let texts=emitted.compactMap { step -> String? in if case .text(let text)=step { return text };return nil }
        XCTAssertEqual(keys,[36,48,36,36]);XCTAssertEqual(texts,["a","b","c","d"])
    }
    func testInvalidKeyModifierAndControlDataReject() throws {
        for chord in [PetKeyChord(keyCode:128,modifiers:[],label:"坏键"),PetKeyChord(keyCode:55,modifiers:[],label:"仅Command"),PetKeyChord(keyCode:8,modifiers:[.command,.command],label:"重复"),PetKeyChord(keyCode:8,modifiers:[],label:"\n")] {
            XCTAssertThrowsError(try PetKeyboardMacro(steps:[.key(chord)]).validate())
        }
        XCTAssertThrowsError(try PetKeyboardMacro(steps:[.text("\u{0}")]).validate())
        XCTAssertThrowsError(try PetKeyboardMacro(steps:[.text("")]).validate())
    }
    func testMacroLimitsAndFutureProtocol() throws {
        XCTAssertThrowsError(try PetKeyboardMacro(steps:[]).validate())
        XCTAssertNoThrow(try PetKeyboardMacro(steps:Array(repeating:.key(copy),count:32)).validate())
        XCTAssertThrowsError(try PetKeyboardMacro(steps:Array(repeating:.key(copy),count:33)).validate())
        XCTAssertThrowsError(try PetKeyboardMacro(steps:[.text(String(repeating:"🙂",count:1025))]).validate())
        XCTAssertThrowsError(try PetKeyboardMacro.decodeTarget(#"{"version":2,"steps":[]}"#))
    }
    func testDeliveryGateRejectsPermissionFocusChangeSelfAndCancel() {
        XCTAssertTrue(PetKeyboardDeliveryGate.canStart(permission:true,frontmostPID:42,ownPID:100,busy:false))
        for args in [(false,42,false),(true,100,false),(true,42,true),(true,0,false)] {
            XCTAssertFalse(PetKeyboardDeliveryGate.canStart(permission:args.0,frontmostPID:args.1,ownPID:100,busy:args.2))
        }
        XCTAssertTrue(PetKeyboardDeliveryGate.canContinue(permission:true,frontmostPID:42,targetPID:42,targetAlive:true,cancelled:false))
        XCTAssertFalse(PetKeyboardDeliveryGate.canContinue(permission:true,frontmostPID:43,targetPID:42,targetAlive:true,cancelled:false))
        XCTAssertFalse(PetKeyboardDeliveryGate.canContinue(permission:false,frontmostPID:42,targetPID:42,targetAlive:true,cancelled:false))
        XCTAssertFalse(PetKeyboardDeliveryGate.canContinue(permission:true,frontmostPID:42,targetPID:42,targetAlive:false,cancelled:false))
        XCTAssertFalse(PetKeyboardDeliveryGate.canContinue(permission:true,frontmostPID:42,targetPID:42,targetAlive:true,cancelled:true))
    }
    func testNativeRecordIsDistinctFromLegacyWindowsKeys() throws {
        let target=try PetKeyboardMacro(steps:[.key(copy)]).encodedTarget()
        let entry=PetShortcutEntry(id:1,name:"复制",kind:.macKeys,target:target)
        XCTAssertNoThrow(try entry.validate());XCTAssertThrowsError(try entry.resolvedURL())
        XCTAssertThrowsError(try PetShortcutEntry(id:1,name:"原文",kind:.macKeys,target:"^(c)").validate())
        XCTAssertNoThrow(try PetShortcutEntry(id:1,name:"保留",kind:.windowsKeys,target:"^(c)").validate())
    }
    func testFutureNestedMacroProtectsBothPrimaryAndBackup() throws {
        for futureInBackup in [false,true] {
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
            let store=PetShortcutStore(directory:dir);var normal=PetShortcutList()
            try normal.edit(.add(name:"网站",kind:.url,target:"https://example.com"));try store.save(normal);try store.save(normal)
            let object:[String:Any]=["version":2,"nextID":2,"entries":[["id":1,"name":"未来宏","kind":"macKeys","target":#"{"version":2,"steps":[]}"#]]]
            let data=try JSONSerialization.data(withJSONObject:object),path=futureInBackup ? store.backup:store.primary
            try data.write(to:path)
            XCTAssertThrowsError(try store.save(normal));XCTAssertEqual(try Data(contentsOf:path),data)
            XCTAssertThrowsError(try store.restoreBackup());XCTAssertEqual(try Data(contentsOf:path),data)
        }
    }
    func testConfigOneUpgradesWithOriginalAndFutureThreeProtected() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        let store=PetShortcutStore(directory:dir)
        let original=Data(#"{"version":1,"entries":[{"id":1,"name":"旧入口","kind":"url","target":"https://example.com"}],"nextID":2}"#.utf8)
        try original.write(to:store.primary)
        var loaded=try store.load();XCTAssertEqual(loaded.version,2);XCTAssertEqual(try Data(contentsOf:store.primary),original)
        try loaded.edit(.add(name:"新复制",kind:.macKeys,target:PetKeyboardMacro(steps:[.key(copy)]).encodedTarget()))
        try store.save(loaded);XCTAssertEqual(try store.load(),loaded)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.migrationOriginal)),original)
        let future=Data(#"{"version":3}"#.utf8);try future.write(to:store.primary)
        XCTAssertThrowsError(try store.save(loaded));XCTAssertEqual(try Data(contentsOf:store.primary),future)
    }
}
