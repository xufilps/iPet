// SPDX-License-Identifier: Apache-2.0
import SwiftUI

@main struct IPetIOSApp: App {
    @StateObject private var model = IOSPetModel.application()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            Group {
                if let error=model.startupError {
                    ContentUnavailableView {
                        Label("无法打开宠物",systemImage:"exclamationmark.triangle")
                    } description: {
                        Text(error + "\n原存档不会被新宠物覆盖。请保留沙盒数据后检查资源或存档版本。")
                    }
                } else { IOSRootView().environmentObject(model) }
            }
            .onChange(of:phase,initial:true) { _,value in model.setActive(value == .active) }
        }
    }
}

struct IOSRootView: View {
    var body: some View {
        TabView {
            Tab("养宠",systemImage:"pawprint.fill") { NavigationStack { IOSHomeView() } }
            Tab("活动",systemImage:"sparkles") { NavigationStack { IOSActivitiesView() } }
            Tab("商店",systemImage:"basket") { NavigationStack { IOSMarketView(inventory:false) } }
            Tab("背包",systemImage:"backpack") { NavigationStack { IOSMarketView(inventory:true) } }
            Tab("设置",systemImage:"gearshape") { NavigationStack { IOSSettingsView() } }
        }
        .tint(.blue)
    }
}
