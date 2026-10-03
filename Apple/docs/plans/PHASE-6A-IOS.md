# iOS 固定角色养宠 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. User chose Native and explicitly requested implementation.

**Goal:** 可启动和操作的iOS26应用，固定角色、活动与买用闭环、后台暂停和安全本地保存。
**Architecture:** SwiftUI原生导航及Liquid Glass控件，UIKit SKView承载共享PetScene，独立主线程应用模型。PetCore增加可注入时钟的前台会话协调器，不依赖UI平台；iOS模型由单一核心实例管理规则和保存。
**Tech Stack:** Swift6、SwiftUI、SpriteKit、UIKit、现有Python工程生成器。
**Spec:** [PHASE-6A-IOS](../specs/PHASE-6A-IOS.md)

## Global Constraints

macOS/iOS/iPadOS最低26；无自主移动；不改规则/JSONv9；内置单角色与本地数据；按需48MiB纹理缓存；后台不补算；无云/联机/语音/插件；macOS回归保留。iOS27运行证据不等于iOS26/真机验收。

## Review Focus

- 重复活跃通知：不能叠加计时器或重复收益，Task1验证幂等激活。
- 切后台前后：活跃尾段正常推进，后台不推进，Task1固定时钟验证。
- 未来/损坏存档：失败模型不覆盖存档，Task2用隔离启动和既有持久化回归验证。
- 页面/动作切换：不能反复启动活动或覆盖投喂贴图，Task2状态同步/事件优先级检查。
- 大字号/旋转/玻璃控件：舞台布局与滚动按钮可达，Task3模拟器布局及辅助功能检查。

### Task 1: 可测的前台会话

**Files:** Sources/PetCore/PetForegroundSession.swift、Tests/PetCoreTests/PetForegroundSessionTests.swift（均在Apple/内）。
**Interfaces:** 消费PetEngine.tick/resetClock；产出PetForegroundSession(engine:clock:)、activate()、deactivate()、tick()->Bool（返回是否达到60秒自动保存间隔）、isActive。
- [x] 写固定时钟测试：重复activate不重置已活跃秒；后台120秒无状态/活动推进；恢复只计前台时间；60秒保存节奏不补算后台；手动暂停不被激活恢复。
- [x] 运行新测试观察缺失类型失败；实现最小协调器后验证通过。
- [x] 提交核心与测试检查点。

### Task 2: 应用、资源与养宠闭环

**Files:** Apps/iOS/iPetApp.swift、IOSPetModel.swift、PetStageView.swift、HomeView.swift、ActivitiesView.swift、MarketView.swift、SettingsView.swift；scripts/create_project.py；Resources/iOSAssets.xcassets。
**Interfaces:** 消费Task1和现有PetSaveStore/Catalog/Scene；模型公开state/catalog/scene/message/saveError、setActive(Bool)、interact(PetCommand)、perform(PetEconomyCommand)、touch(CGPoint)、showPreview()、updateSpeechSettings()；UIKit视图负责场景坐标映射/透明区域拒绝，不移动角色。
- [x] 新增iOS目标与共享scheme，应用沙盒ApplicationSupport/iPet、启动错误页和不覆盖存档保护；一个Timer由模型持有，每次不活跃失效并保存。
- [x] 固定舞台、触摸、免费食水贴图、活动循环结束与买用入口；SwiftUI TabView/NavigationStack/原生sheet，舞台浮动操作采用GlassEffectContainer/玻璃按钮。
- [x] 本地消息参数使用PetSpeechSettings/Playback，预览不结算；消息完成回调仅一次，后台关闭消息并复位计时。
- [x] 同步工程生成器、iOS图标与授权资源；构建iOS Simulator，编译诊断逐项修复；提交应用检查点。

### Task 3: 验证与交付

**Files:** scripts/build-ios.sh、verify.sh、verify_repository.py、README/Apple README、docs/IOS.md/HANDOFF/UPSTREAM_COMPARISON/REMAINING-FEATURES/ROADMAP。
**Interfaces:** build-ios.sh产出build/iOS/Build/Products/Release-iphonesimulator/iPet-iOS.app，使用共享scheme iPet-iOS，无开发者凭证；verify.sh同时检查macOS与iOS应用。
- [x] 全套现有Swift/Python、双平台构建/签名与项目生成一致性；检查Info.plist/AppIcon最低版本26及原许可字节。
- [x] 实际启动iPhone/iPad模拟器，检查舞台/菜单/贴图与启动失败日志，交互可检查部分记录证据，设备/26运行时/长期压力列待验。
- [x] 独立6.1-sol审查整批，重要问题修复后回归；提交、ff至ipet-dev、推送并核对远程SHA。

## 风险、回滚与交付

原帧资源大，移动设备性能未知；模拟器不承诺真机效果；复制与旧档导入/排程/套餐/统计详细页为后续UI迁移。回滚本批代码与工程重建，不删除用户ApplicationSupport/不迁移JSON。授权与资源来源随两个应用一起打包。用户“实施吧”是本计划Native执行授权，不增加重复审批。

执行记录：Native完成三项代码/自动验证交付。Simulator实际启动及截图检查完成，无法由当前工具操作全部模拟器控件，触摸/动效/辅助功能和设备验证依规格边界保留待验；不以勾选表示实机阶段完成。独立审查一项重要缺陷与作者发现预览缺陷均RED→GREEN。
