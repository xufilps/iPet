// iPet: Swift native adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    func applicationDidFinishLaunching(_ notification: Notification) {
        do { try model.start() }
        catch {
            let alert = NSAlert(); alert.messageText = "无法启动 iPet"; alert.informativeText = error.localizedDescription
            alert.runModal(); NSApp.terminate(nil)
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
