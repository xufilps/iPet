// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PetCore
final class PetShortcutTests:XCTestCase {
    func testCRUDKeepsIdentityAndFailedEditIsAtomic() throws {
        var list=PetShortcutList()
        try list.edit(.add(name:"网站",kind:.url,target:"https://example.com"))
        try list.edit(.add(name:"文档",kind:.file,target:"/tmp/中文 文件.md"))
        try list.edit(.update(1,name:"新网站",kind:.url,target:"https://example.org/path"))
        XCTAssertEqual(list.entries.map(\.id),[1,2]);XCTAssertEqual(list.entries[0].name,"新网站")
        let before=list
        XCTAssertThrowsError(try list.edit(.update(1,name:"",kind:.url,target:"https://example.com")));XCTAssertEqual(list,before)
        XCTAssertThrowsError(try list.edit(.remove(999)));XCTAssertEqual(list,before)
        try list.edit(.remove(1));try list.edit(.add(name:"第三项",kind:.url,target:"music://"))
        XCTAssertEqual(list.entries.map(\.id),[2,3])
    }
    func testMoveToFrontAndBackPreservesEntries() throws {
        var list=PetShortcutList()
        for name in ["a","b","c"] { try list.edit(.add(name:name,kind:.url,target:"https://example.com")) }
        try list.edit(.front(3));XCTAssertEqual(list.entries.map(\.id),[3,1,2])
        try list.edit(.back(3));XCTAssertEqual(list.entries.map(\.id),[1,2,3])
    }
    func testURLAndFileAreExplicitAndNoShellOrWindowsGuessing() throws {
        let link=PetShortcutEntry(id:1,name:"链接",kind:.url,target:"https://example.com/中文?q=hello%20world")
        XCTAssertEqual(try link.resolvedURL().host,"example.com")
        let path=PetShortcutEntry(id:2,name:"文件",kind:.file,target:"/tmp/中文 文件;$(echo literal).md")
        XCTAssertEqual(try path.resolvedURL().path,"/tmp/中文 文件;$(echo literal).md")
        for address in ["example.com","https:///missing","javascript://alert(1)","data://text/plain","file:///tmp/a","https://example.com\n"] {
            XCTAssertThrowsError(try PetShortcutEntry(id:1,name:"坏链接",kind:.url,target:address).validate())
        }
        for path in ["relative.md","C:\\app.exe","/tmp/a\u{0}"] {
            XCTAssertThrowsError(try PetShortcutEntry(id:1,name:"坏路径",kind:.file,target:path).validate())
        }
        XCTAssertEqual(try PetShortcutEntry(id:1,name:"邮件",kind:.url,target:"mailto:user@example.com").resolvedURL().scheme,"mailto")
    }
    func testUnicodeJoinedEmojiInNamesAndPathsRemainsLiteral() throws {
        let path="/tmp/👨‍👩‍👧‍👦.md"
        let entry=PetShortcutEntry(id:1,name:"家庭👨‍👩‍👧‍👦",kind:.file,target:path)
        try entry.validate();XCTAssertEqual(try entry.resolvedURL().path,path)
    }
    func testWindowsKeyRecordSurvivesButCannotExecute() throws {
        var list=PetShortcutList();try list.edit(.add(name:"原键序列",kind:.windowsKeys,target:"^(c)"))
        let loaded=try JSONDecoder().decode(PetShortcutList.self,from:JSONEncoder().encode(list))
        XCTAssertEqual(loaded,list);XCTAssertThrowsError(try loaded.entries[0].resolvedURL())
    }
    func testCapacityAndMalformedDocumentRejectWithoutMutation() throws {
        var list=PetShortcutList()
        for _ in 0..<1000 { try list.edit(.add(name:"网站",kind:.url,target:"https://example.com")) }
        let before=list;XCTAssertThrowsError(try list.edit(.add(name:"满",kind:.url,target:"https://example.com")));XCTAssertEqual(list,before)
        XCTAssertThrowsError(try PetShortcutEntry(id:1,name:String(repeating:"字",count:101),kind:.url,target:"https://example.com").validate())
        for raw in [#"{"version":3,"entries":[],"nextID":1}"#,#"{"version":1,"entries":[],"nextID":0}"#,#"{"version":1,"entries":[{"id":1,"name":"a","kind":"url","target":"https://example.com"},{"id":1,"name":"b","kind":"url","target":"https://example.com"}],"nextID":2}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(PetShortcutList.self,from:Data(raw.utf8)))
        }
    }
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func list(_ name:String) throws -> PetShortcutList {
        var list=PetShortcutList();try list.edit(.add(name:name,kind:.url,target:"https://example.com"));return list
    }
    func testAtomicRoundTripAndPreviousBackup() throws {
        let dir=directory();defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetShortcutStore(directory:dir),first=try list("第一版"),second=try list("第二版")
        try store.save(first);try store.save(second)
        XCTAssertEqual(try store.load(),second)
        XCTAssertEqual(try JSONDecoder().decode(PetShortcutList.self,from:Data(contentsOf:store.backup)),first)
    }
    func testFuturePrimaryAndBackupNeverOverwrittenOrRestored() throws {
        for futureInBackup in [false,true] {
            let dir=directory();defer { try? FileManager.default.removeItem(at:dir) }
            let store=PetShortcutStore(directory:dir),value=try list("安全")
            try store.save(value);try store.save(value)
            let path=futureInBackup ? store.backup:store.primary,bytes=Data(#"{"version":3,"entries":[]}"#.utf8)
            try bytes.write(to:path)
            XCTAssertThrowsError(try store.save(value));XCTAssertEqual(try Data(contentsOf:path),bytes)
            XCTAssertThrowsError(try store.restoreBackup());XCTAssertEqual(try Data(contentsOf:path),bytes)
        }
    }
    func testCorruptPrimaryIsRetainedUntilExplicitBackupRestore() throws {
        let dir=directory();defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetShortcutStore(directory:dir),first=try list("旧"),second=try list("新")
        try store.save(first);try store.save(second)
        let corrupt=Data("broken".utf8);try corrupt.write(to:store.primary)
        XCTAssertThrowsError(try store.load());XCTAssertEqual(try Data(contentsOf:store.primary),corrupt)
        XCTAssertThrowsError(try store.save(second));XCTAssertEqual(try Data(contentsOf:store.primary),corrupt)
        XCTAssertEqual(try store.restoreBackup(),first)
        XCTAssertEqual(try Data(contentsOf:XCTUnwrap(store.recoveryOriginal)),corrupt)
    }
    func testWriteFailureCannotReplaceOldDocument() throws {
        let dir=directory();defer { try? FileManager.default.removeItem(at:dir) }
        let store=PetShortcutStore(directory:dir),value=try list("保留")
        try store.save(value);let before=try Data(contentsOf:store.primary)
        try FileManager.default.createDirectory(at:store.backup,withIntermediateDirectories:false)
        XCTAssertThrowsError(try store.save(try list("失败")))
        XCTAssertEqual(try Data(contentsOf:store.primary),before)
    }
}
