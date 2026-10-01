# Windows 原版与 iPet 的持续差异矩阵

原版基线：`1a06c5981330564bab05a098d2d7969a4b119dd3`；iPet 基线：v0.1.0，当前图标与文档修订。原版功能依据本仓库源码，不将第三方插件功能算作内置功能；当前行为依据 Apple 源码和已记录验证。后续每次迁移更新本表、行为说明和交接记录。源码入口编号在文末，阶段对应 [ROADMAP.md](ROADMAP.md)。

状态定义：**已保留**为纳入范围的原规则已移植；**已适配**为平台或产品行为有明确变化；**部分实现**为有可用子集；**尚未迁移**为没有原生实现；**需要平台替代**为原机制不能直接复用；**待验证**为代码或构建证据不足以完成验收。状态指本行能力，不代表整个类别完成。

| 能力 | 原版行为 | iPet 当前行为 | 差异原因 | 状态 | 源码依据（原版 → iPet） | 阶段 |
| --- | --- | --- | --- | --- | --- | --- |
| 平台与窗口 | C#/.NET/WPF，Win32 桌面窗口 | Swift6/AppKit/SpriteKit/SwiftUI，macOS14+ | 原生重建窗口与界面 | 已适配 | U1 → A1 | 0、1 |
| 穿透与焦点 | WPF/Win32 输入与窗口设置 | 30Hz 当前帧 alpha 穿透；桌宠不能成为主键盘窗口 | 平台机制不同，快速点击/真实拖动仍待验 | 待验证 | U1 → A1 | 1 |
| 显示器与睡眠 | Windows 移动边界、定时器和保存生命周期 | 屏幕变化重新约束位置；睡眠保存、暂停，恢复重置计时基准 | AppKit 生命周期适配，实机检查未完整完成 | 待验证 | U1、U3、U7 → A1 | 1 |
| 基础状态属性 | 体力、饱腹、饮水、心情、健康、经验、好感及 setter 副作用 | 保留对应字段、截断和副作用；固定输入测试 | 纳入首版规则移植 | 已保留 | U2 → A2 | 2 |
| 状态判断 | CalMode 健康、心情、好感阈值 | 保留判断次序和比较边界 | 纳入首版规则移植 | 已保留 | U2 → A2 | 2 |
| 日常/休息推进 | FunctionSpend 按活动分支推进 | 移植默认/休息分支，15秒逻辑步长；工作分支缺失 | 活动范围缩减 | 部分实现 | U3 → A2 | 2 |
| 离线时间 | 已查定时器和主加载路径未见离线养成补算 | 不新增退出/睡眠扣减；长调度间隔不追补 | 保守移植和平台生命周期适配；不是全插件路径审计 | 已适配 | U3、U7 → A1、A2 | 1、2 |
| 抚摸与投喂公式 | 抚摸体力消耗/心情恢复；EatFood 一半即时、一半缓释；StoreTake 尾数处理 | 保留纳入规则，包括原边界和运算顺序 | 子规则对照，不等于完整商店 | 已保留 | U2、U4 → A2 | 2 |
| 食物参数与图片 | 数据定义食物属性、价格、类型、图片 | 免费面包/饮料：新增参数及 emoji 图像 | 首版可自用的简化入口 | 已适配 | U5、U6 → A1、A2、A3 | 2、3 |
| 工作/学习/娱乐 | Work 类型、效率、状态消耗、金钱或经验收益和计时窗口 | 未实现活动及收益循环 | 首版范围限制 | 尚未迁移 | U3、U6 → A2 | 2 |
| 商店/库存/物品 | 购买、库存、不同类别物品与使用统计 | 无购买、库存或物品体系 | 免费投喂不能替代经济系统 | 尚未迁移 | U5、U6、U7 → A1、A2 | 2 |
| 疾病与药品 | Ill 状态、活动中止和药品消费 | 可判断低健康；通过免费投喂/休息恢复，无疾病治疗系统 | 首版恢复途径简化 | 部分实现 | U2、U3、U5、U7 → A2 | 2 |
| 经验/好感与金钱 | 完整养成/活动收益和金钱记录 | 基础经验/好感已移植，未实现金钱玩法 | 收益路径未迁移 | 部分实现 | U2、U3 → A2 | 2 |
| 动画帧与阶段 | 图层、开始/循环/结束、状态动画及变体 | 保留选用帧的时长、自然排序、阶段与食物图层运动 | 首版按动作选取资源 | 部分实现 | U4、U8 → A3、A4 | 3 |
| 动作规模与随机池 | 完整角色动画、变体和随机互动池 | 27个动作/状态组合、559个唯一PNG；每组合/阶段确定选一个变体 | 缩小资源包和首版范围；27不是27种完整活动 | 部分实现 | U3、U4、U8 → A3、A4 | 3 |
| 触摸/提起/行走 | 原配置触摸区及动作逻辑 | 映射头/身体区域，拖动暂停自主移动，基础左右走 | 平台输入适配；触摸区使用500逻辑画布 | 已适配 | U4、U8 → A1、A3 | 1、3 |
| 爬墙/边缘隐藏/移动区域 | 原版边缘检查、移动区与相关动作 | 限于可见区域，未实现爬墙、边缘隐藏/跨屏自主漫游 | 需新窗口边界行为 | 尚未迁移 | U3、U4、U6 → A1 | 3 |
| 动作打断/回退 | 原 Graph 调度与状态切换 | 新时间线替换；缺状态按清单回退并诊断 | SpriteKit 调度及资源子集适配 | 已适配 | U3、U8 → A3 | 3 |
| 面板/工具栏/说话栏 | WPF设置、工具栏、对话及各功能窗口 | 中文 SwiftUI 状态/大小/移动设置和菜单栏；无完整工具栏/说话栏 | WPF不能原样作为SwiftUI界面运行 | 部分实现 | U1、U6、U9 → A1 | 3 |
| 原作资源与新图标 | 原图标、角色、LPS配置与PNG | 保留原目录；新像素风参考图标，LPS构建前转JSON；运行时不依赖LPS | 原生资源目录与资源子集 | 已适配 | U8 → A4、A5 | 0、3 |
| 多角色与数据MOD | PetLoader/CoreMOD加载角色、食物、文本等 | 仅内置萝莉斯子集；无第三方数据加载接口 | 转换工具不是通用MOD兼容器 | 尚未迁移 | U5、U8、U10 → A4 | 4 |
| 主题/文本/本地化 | Theme、MOD文本及本地化资源 | 固定简体中文原生界面 | 需要新数据模型和界面主题适配 | 尚未迁移 | U5、U9、U10 → A1 | 4 |
| 本地存档安全 | LPS养成/设置及多存档管理 | Codable版本JSON，原子保存、有效备份、损坏保留和未来版本阻写 | 独立格式；历史VPetApple目录保留 | 已适配 | U7、U11 → A2 | 2、4 |
| 旧LPS存档导入 | 原版读取自己的LPS格式 | 无导入，不读写原Windows存档 | 需字段映射、版本和一次性迁移协议 | 尚未迁移 | U7、U11 → A2 | 4 |
| C#代码插件 | CLR程序集加载、MainPlugin和原接口 | 不兼容C# ABI、事件或WPF插件界面 | Swift不能直接执行原插件；与数据MOD任务不同 | 需要平台替代 | U10、U12 → A1、A2 | 5研究 |
| 排程/统计/活动日志 | ScheduleTask、Statistics、ActivityLog | 无完整原版排程、统计和活动记录 | 原版周边功能后续迁移 | 尚未迁移 | U7、U13 → A1、A2 | 5 |
| 图库及其余功能 | Gallery、Console、保存管理等独立功能 | 未提供，原代码保留 | 分项梳理；图库另有授权限制 | 尚未迁移 | U6、U7 → A1 | 5研究 |
| Steam/云存档/工坊 | SteamRemoteStorage、工坊和验证客户端 | 无接入、云同步或订阅更新 | SDK、账户与分发条件需独立研究 | 需要平台替代 | U7、U10、U14 → A1 | 5研究 |
| 联机/对话生态 | MutiPlayer接口；TalkBox及插件可扩展对话 | 无联机、AI服务或网络对话 | 不将插件能力视为内置AI已移植 | 尚未迁移 | U9、U12、U14 → A1 | 5研究 |
| iOS | 本基线Windows工程，无原生iOS产品 | PetCore/PetRendering Simulator编译通过，无iOS界面/真机证据 | 移动应用内养宠另做前后台适配 | 待验证 | U1 → A6 | 6 |
| 发行与许可证 | 原README渠道及Apache代码/独立素材授权 | GitHub源码、自用ad-hoc构建；原署名/许可随包，无签名公证发行包 | 发行准备未完成；素材授权独立 | 部分实现 | 原README、LICENSE → A5、A7 | 0、6 |
| 性能和稳定性 | 原版实现不能单凭源码推断性能 | 缓存估算48MiB、按帧加载；120秒观察及16测试；两小时实机待验 | 无同条件Windows对照，不能声称更省资源/稳定 | 待验证 | U8 → A3、A7 | 1 |

## 可复核的源码入口

以下链接指向仓库保留的原源码；复核历史时用 `git show 1a06c598:<路径>`。iPet源码依据为当前版本，新增功能应更新本矩阵而不是删除历史差异原因。

- U1：[Windows项目](../../VPet-Simulator.Windows/VPet-Simulator.Windows.csproj)、[Win32](../../VPet-Simulator.Windows/Function/Win32.cs)、[控制器](../../VPet-Simulator.Windows/Function/MWController.cs)。
- U2：[GameSave.cs](../../VPet-Simulator.Core/Handle/GameSave.cs)：EatFood、StoreTake、CalMode及属性setter。
- U3：[MainLogic.cs](../../VPet-Simulator.Core/Display/MainLogic.cs)：FunctionSpend、EventTimer_Elapsed、MoveSideHideCheck、WorkList、StartWork。
- U4：[MainDisplay.cs](../../VPet-Simulator.Core/Display/MainDisplay.cs)：头/身体互动及显示入口。
- U5：[物品](../../VPet-Simulator.Windows.Interface/Mod/Item.cs)、[食物](../../VPet-Simulator.Windows.Interface/Mod/Food.cs)、[点击文本](../../VPet-Simulator.Windows.Interface/Mod/ClickText.cs)。
- U6：[原版窗口目录](../../VPet-Simulator.Windows/WinDesign)：winInventory、winBetterBuy、winWorkMenu、winGallery、winSaveManager、winGameSetting、winMoveArea、winConsole。
- U7：[MainWindow.cs](../../VPet-Simulator.Windows/MainWindow.cs)：保存/加载、购买使用、统计、Steam存档。
- U8：[PetLoader](../../VPet-Simulator.Core/Handle/PetLoader.cs)、[Graph目录](../../VPet-Simulator.Core/Graph)、[内置角色配置](../../VPet-Simulator.Windows/mod/0000_core/pet/vup.lps)。
- U9：[Theme](../../VPet-Simulator.Windows.Interface/Theme.cs)、[TalkBox](../../VPet-Simulator.Windows.Interface/TalkBox.xaml.cs)。
- U10：[CoreMOD](../../VPet-Simulator.Windows/Function/CoreMOD.cs)：LoadPlug、LoadFile、角色/文本/本地化及DLL加载。
- U11：[GameSave_v2](../../VPet-Simulator.Windows.Interface/GameSave_v2.cs)、[GameSave_VPet](../../VPet-Simulator.Windows.Interface/GameSave_VPet.cs)。
- U12：[MainPlugin](../../VPet-Simulator.Windows.Interface/MainPlugin.cs)、[IMainWindow](../../VPet-Simulator.Windows.Interface/IMainWindow.cs)。
- U13：[排程](../../VPet-Simulator.Windows.Interface/ScheduleTask.cs)、[统计](../../VPet-Simulator.Windows.Interface/Statistics.cs)、[活动日志](../../VPet-Simulator.Windows.Interface/ActivityLog.cs)。
- U14：[工坊验证客户端](../../VPet-Simulator.Windows/Function/WorkshopVerificationClient.cs)、[联机接口](../../VPet-Simulator.Windows.Interface/MutiPlayer)。
- A1：[AppModel](../Sources/iPetMac/AppModel.swift)、[PetWindow](../Sources/iPetMac/PetWindow.swift)、[ControlsView](../Sources/iPetMac/ControlsView.swift)。
- A2：[PetEngine](../Sources/PetCore/PetEngine.swift)、[PetState](../Sources/PetCore/PetState.swift)、[PetSaveStore](../Sources/PetCore/PetSaveStore.swift)；具体保留公式见 [BEHAVIOR.md](BEHAVIOR.md)。
- A3：[PetScene](../Sources/PetRendering/PetScene.swift)、[Manifest](../Sources/PetRendering/Manifest.swift)。
- A4：[资源转换器](../scripts/convert_assets.py)，生成清单不等同完整LPS解析器。
- A5：[图标记录](../Design/README.md)、[来源](../ATTRIBUTION.md)、[素材授权](../ANIMATION_LICENSE.md)。
- A6：[Package.swift](../Package.swift)、[验证脚本](../scripts/verify.sh)。
- A7：[构建脚本](../scripts/build.sh)、[交接与验证边界](HANDOFF.md)。

本表覆盖当前已识别的原版能力家族，目录内更细的选项、插件和第三方内容不声称穷尽。每阶段规格需扩展逐场景清单，新增发现必须分配状态、源码入口和阶段；未复核的能力保持待验证，不以编译成功代替行为等价。
