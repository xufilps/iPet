# Windows 原版与 iPet 的持续差异矩阵

原版基线：`1a06c5981330564bab05a098d2d7969a4b119dd3`；iPet 基线：v0.2.0，阶段2养成与经济实现；部分实机验收已记录，压力测试按用户要求留到功能完善后。原版功能依据上游固定基线源码，不将第三方插件功能算作内置功能；当前行为依据 Apple 源码和已记录验证。后续每次迁移更新本表、行为说明和交接记录。源码入口编号在文末，阶段对应 [ROADMAP.md](ROADMAP.md)。

状态定义：**已保留**为纳入范围的原规则已移植；**已适配**为平台或产品行为有明确变化；**部分实现**为有可用子集；**尚未迁移**为没有原生实现；**需要平台替代**为原机制不能直接复用；**待验证**为代码或构建证据不足以完成验收。状态指本行能力，不代表整个类别完成。

| 能力 | 原版行为 | iPet 当前行为 | 差异原因 | 状态 | 源码依据（原版 → iPet） | 阶段 |
| --- | --- | --- | --- | --- | --- | --- |
| 平台与窗口 | C#/.NET/WPF，Win32 桌面窗口 | Swift6/AppKit/SpriteKit/SwiftUI，macOS14+ | 原生重建窗口与界面 | 已适配 | U1 → A1 | 0、1 |
| 穿透与焦点 | WPF/Win32 输入与窗口设置 | 30Hz 当前帧 alpha 穿透；桌宠不能成为主键盘窗口 | 平台机制不同；本机拖动、穿透与焦点已有记录，快速点击及更多设备仍待验 | 部分实现 | U1 → A1 | 1 |
| 显示器与睡眠 | Windows 移动边界、定时器和保存生命周期 | 屏幕变化重新约束位置；睡眠保存、暂停，恢复重置计时基准 | AppKit 生命周期适配，实机检查未完整完成 | 待验证 | U1、U3、U7 → A1 | 1 |
| 基础状态属性 | 体力、饱腹、饮水、心情、健康、经验、好感及 setter 副作用 | 保留对应字段、截断和副作用；固定输入测试 | 纳入首版规则移植 | 已保留 | U2 → A2 | 2 |
| 状态判断 | CalMode 健康、心情、好感阈值 | 保留判断次序和比较边界 | 纳入首版规则移植 | 已保留 | U2 → A2 | 2 |
| 日常/休息推进 | FunctionSpend 按活动分支推进 | 移植默认/休息/活动分支，15秒逻辑步长及活动时长推进 | 活动范围缩减 | 部分实现 | U3 → A2 | 2 |
| 离线时间 | 已查定时器和主加载路径未见离线养成补算 | 不新增退出/睡眠扣减；长调度间隔不追补 | 保守移植和平台生命周期适配；不是全插件路径审计 | 已适配 | U3、U7 → A1、A2 | 1、2 |
| 抚摸与投喂公式 | 抚摸体力消耗/心情恢复；EatFood 一半即时、一半缓释；StoreTake 尾数处理 | 保留纳入规则，包括原边界和运算顺序 | 子规则对照，不等于完整商店 | 已保留 | U2、U4 → A2 | 2 |
| 食物参数与图片 | 数据定义食物属性、价格、类型、图片 | 118项原物品、原PNG图片、七种类别与重复食用衰减 | 恢复内置物品；限时4项排除 | 已适配 | U5、U6 → A1、A2、A3 | 2、3 |
| 工作/学习/娱乐 | Work 类型、效率、状态消耗、金钱或经验收益和计时窗口 | 13内置活动、原默认自动平衡、效率/收益/完成奖金及暂停恢复 | 仅内置活动，原UI计时器改为核心单一计时 | 已适配 | U3、U6 → A2 | 2 |
| 商店/库存/物品 | 购买、库存、不同类别物品与使用统计 | 购买即用/入包、库存数量与使用；没有原版完整统计 | 仅内置目录，不支持第三方扩展 | 部分实现 | U5、U6、U7 → A1、A2 | 2 |
| 疾病与药品 | Ill 状态、活动中止和药品消费 | Ill判断、活动状态失败中止、原药品及免费应急药代价 | 首版恢复途径简化 | 部分实现 | U2、U3、U5、U7 → A2 | 2 |
| 经验/好感与金钱 | 完整养成/活动收益和金钱记录 | 经验/好感、金币与工作/学习/娱乐收益已移植 | 原版完整统计尚未迁移 | 部分实现 | U2、U3 → A2 | 2 |
| 动画帧与阶段 | 图层、开始/循环/结束、状态动画及变体 | 保留选用帧的时长、自然排序、阶段与食物图层运动 | 首版按动作选取资源 | 部分实现 | U4、U8 → A3、A4 | 3 |
| 动作规模与随机池 | 完整角色动画、变体和随机互动池 | 77个动作/Graph/状态组合、2493个唯一PNG；Default/抚摸/Boring/Squat按阶段抽取变体，其余保留子集 | 缩小资源包和首版范围；组合数不是完整活动种数 | 部分实现 | U3、U4、U8 → A3、A4 | 3 |
| 触摸/提起/行走 | 原配置触摸区及动作逻辑 | 映射头/身体区域，拖动暂停自主移动，基础左右走 | 平台输入适配；触摸区使用500逻辑画布 | 已适配 | U4、U8 → A1、A3 | 1、3 |
| 爬墙/边缘隐藏/移动区域 | 原版边缘检查、移动区与相关动作 | 限于可见区域，未实现爬墙、边缘隐藏/跨屏自主漫游 | 需新窗口边界行为 | 尚未迁移 | U3、U4、U6 → A1 | 3 |
| 动作打断/回退 | 原 Graph 调度与状态切换 | 新时间线替换；缺状态按清单回退并诊断 | SpriteKit 调度及资源子集适配 | 已适配 | U3、U8 → A3 | 3 |
| 面板/工具栏/说话栏 | WPF设置、工具栏、对话及各功能窗口 | 中文 SwiftUI 状态/活动/商店/背包/设置和菜单栏；无完整工具栏/说话栏 | WPF不能原样作为SwiftUI界面运行 | 部分实现 | U1、U6、U9 → A1 | 3 |
| 原作资源与新图标 | 原图标、角色、LPS配置与PNG | 保留原目录；新像素风参考图标，LPS构建前转JSON；运行时不依赖LPS | 原生资源目录与资源子集 | 已适配 | U8 → A4、A5 | 0、3 |
| 多角色与数据MOD | PetLoader/CoreMOD加载角色、食物、文本等 | 仅内置萝莉斯子集；无第三方数据加载接口 | 转换工具不是通用MOD兼容器 | 尚未迁移 | U5、U8、U10 → A4 | 4 |
| 主题/文本/本地化 | Theme、MOD文本及本地化资源 | 固定简体中文原生界面 | 需要新数据模型和界面主题适配 | 尚未迁移 | U5、U9、U10 → A1 | 4 |
| 本地存档安全 | LPS养成/设置及多存档管理 | Codable JSON v2，v1升级原件保留、原子保存、损坏恢复和未来版本阻写 | 独立格式；历史VPetApple目录保留 | 已适配 | U7、U11 → A2 | 2、4 |
| 旧LPS存档导入 | 原版读取自己的LPS格式 | 无导入，不读写原Windows存档 | 需字段映射、版本和一次性迁移协议 | 尚未迁移 | U7、U11 → A2 | 4 |
| C#代码插件 | CLR程序集加载、MainPlugin和原接口 | 不兼容C# ABI、事件或WPF插件界面 | Swift不能直接执行原插件；与数据MOD任务不同 | 需要平台替代 | U10、U12 → A1、A2 | 5研究 |
| 排程/统计/活动日志 | ScheduleTask、Statistics、ActivityLog | 无完整原版排程、统计和活动记录 | 原版周边功能后续迁移 | 尚未迁移 | U7、U13 → A1、A2 | 5 |
| 图库及其余功能 | Gallery、Console、保存管理等独立功能 | 未提供，原代码可在上游或Git历史查阅 | 分项梳理；图库另有授权限制 | 尚未迁移 | U6、U7 → A1 | 5研究 |
| Steam/云存档/工坊 | SteamRemoteStorage、工坊和验证客户端 | 无接入、云同步或订阅更新 | SDK、账户与分发条件需独立研究 | 需要平台替代 | U7、U10、U14 → A1 | 5研究 |
| 联机/对话生态 | MutiPlayer接口；TalkBox及插件可扩展对话 | 无联机、AI服务或网络对话 | 不将插件能力视为内置AI已移植 | 尚未迁移 | U9、U12、U14 → A1 | 5研究 |
| iOS | 本基线Windows工程，无原生iOS产品 | PetCore/PetRendering Simulator编译通过，无iOS界面/真机证据 | 移动应用内养宠另做前后台适配 | 待验证 | U1 → A6 | 6 |
| 发行与许可证 | 原README渠道及Apache代码/独立素材授权 | GitHub源码、自用ad-hoc构建；原署名/许可随包，无签名公证发行包 | 发行准备未完成；素材授权独立 | 部分实现 | 原README、LICENSE → A5、A7 | 0、6 |
| 性能和稳定性 | 原版实现不能单凭源码推断性能 | 缓存估算48MiB、按帧加载；v0.1历史120秒观察；当前共59个Swift测试，短时实机记录不替代长期观察；两小时留到功能完善后 | 无同条件Windows对照，不能声称更省资源/稳定 | 待验证 | U8 → A3、A7 | 1 |

## 2026-10-02 逐功能复核补充

当前缺口与建议顺序详见 [REMAINING-FEATURES.md](REMAINING-FEATURES.md)。以下将原先“动作/界面/其余功能”的大项拆开，避免已实现经济闭环掩盖体验缺口。

| 能力 | 原版行为 | iPet 当前行为 | 差异原因 | 状态 | 源码依据（原版 → iPet） | 阶段 |
| --- | --- | --- | --- | --- | --- | --- |
| 自主互动调度 | 移动、待机、特殊待机、睡眠及扩展随机池，概率受InteractionCycle/CountNomal影响 | 15秒抽选，区间max(20,200-默认动画循环次数)；左右走、Boring/Squat、短时打盹；忙碌时不触发 | 抽选分支已接入；特殊待机/扩展池、活动中互动及原随机循环退出尚缺 | 部分实现 | U3 → A1 | 3 |
| 状态过渡动画 | PlaySwitchAnimat沿状态顺序播放Switch_Up/Down | 在默认/过渡动作中逐级播放6种过渡组合；忙碌时不插入；支持取消与新目标 | 原顺序移植，缺帧时诊断/退到目标状态，完整实机待验 | 已适配 | U3 → A1、A3、A4 | 3 |
| 按压/连续抚摸 | 长按阈值、触摸动作匹配；同触摸动作可延续循环 | 300ms原状态区域长按提起；位移超过4点拖动；同抚摸开始不重播、循环续一次 | 当前输入状态机简化 | 部分实现 | U4、Core/Display/Main.xaml.cs → A1 | 3 |
| 角色文本反馈 | ClickText、LowText、SelectText及MessageBar/TalkBox | 671条原文案、点击条件/效果及空闲饥渴提醒；非激活原生气泡，未含选项式聊天 | 原文本规则已迁移，自动提醒限空闲；原说话动画、队列与SelectText尚缺 | 部分实现 | U3、U5、U9、U10 → A1 | 3、4 |
| 语音播放接口 | Main.PlayVoice、音量及播放完成/失败处理 | 无音频播放层 | 需原生接口与可分发语音资源确认；不代表内置角色一定配有语音 | 尚未迁移 | Core/Display/Main.xaml.cs → A1 | 3、5 |
| 库存便捷操作 | 搜索、类别、名称/数量/价格排序、收藏、数量选择使用、总价值 | 按ID排列、逐件使用；商店有搜索和类别 | 原生库存页仅基本操作 | 部分实现 | U6 winInventory → A1 | 2、3 |
| 养成/移动设置 | 养成开关/固定显示状态、互动周期、智能移动、自定移动范围等 | 仅自主移动开关、大小、隐藏和重置 | 仅实现基础偏好 | 部分实现 | U6 winGameSetting → A1 | 3 |
| 窗口显示设置 | 顶层/穿透切换、透明度、消息框位置、快捷小标等 | 固定浮动窗口、按角色alpha自动穿透，没有这些可选项 | 需筛选macOS适用项并原生重建 | 部分实现 | U1、U6 → A1 | 3 |
| 存档管理界面 | 查看/选择存档、多开档、新建/重开等 | 单JSON档、备份恢复与v1升级；只有打开存档目录入口 | 安全保存已实现，管理操作未迁移 | 部分实现 | U6、U7、U11 → A1、A2 | 4、5 |
| 自定义菜单链接/控制台/报告 | DIY菜单、链接设置、控制台及报告窗口 | 无对应入口 | 周边功能未纳入当前实现 | 尚未迁移 | U6、U9、ToolBar → A1 | 5 |
| 开机启动 | Windows启动设置及Steam启动选项 | 不提供 | macOS需独立登录项实现，原计划默认不纳入首版 | 需要平台替代 | U6 → A1 | 6或单独规格 |

上述“尚未迁移”依据固定基线与当前源码；尚未做同条件Windows实机复现的细节不宣称精确行为等价。Travel只发现状态/显示扩展入口，不能据此认定原版内置完整旅行玩法，仍需独立追踪。

## 可复核的源码入口

原C#源码已从iPet当前树移除，以下链接指向原仓库固定基线；也可在保留的Git历史中用 `git show 1a06c598:<路径>` 复核。目录入口可在GitHub打开浏览，不依赖本地原工程。iPet源码依据为当前版本，新增功能应更新本矩阵而不是删除历史差异原因。

- U1：[Windows项目](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/VPet-Simulator.Windows.csproj)、[Win32](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/Function/Win32.cs)、[控制器](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/Function/MWController.cs)。
- U2：[GameSave.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Core/Handle/GameSave.cs)：EatFood、StoreTake、CalMode及属性setter。
- U3：[MainLogic.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Core/Display/MainLogic.cs)：FunctionSpend、EventTimer_Elapsed、MoveSideHideCheck、WorkList、StartWork。
- U4：[MainDisplay.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Core/Display/MainDisplay.cs)：头/身体互动及显示入口。
- U5：[物品](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Mod/Item.cs)、[食物](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Mod/Food.cs)、[点击文本](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Mod/ClickText.cs)。
- U6：[原版窗口目录](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/WinDesign)：winInventory、winBetterBuy、winWorkMenu、winGallery、winSaveManager、winGameSetting、winMoveArea、winConsole。
- U7：[MainWindow.cs](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/MainWindow.cs)：保存/加载、购买使用、统计、Steam存档。
- U8：[PetLoader](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Core/Handle/PetLoader.cs)、[Graph目录](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Core/Graph)、[内置角色配置](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/mod/0000_core/pet/vup.lps)。
- U9：[Theme](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Theme.cs)、[TalkBox](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/TalkBox.xaml.cs)。
- U10：[CoreMOD](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/Function/CoreMOD.cs)：LoadPlug、LoadFile、角色/文本/本地化及DLL加载。
- U11：[GameSave_v2](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/GameSave_v2.cs)、[GameSave_VPet](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/GameSave_VPet.cs)。
- U12：[MainPlugin](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/MainPlugin.cs)、[IMainWindow](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/IMainWindow.cs)。
- U13：[排程](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/ScheduleTask.cs)、[统计](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/Statistics.cs)、[活动日志](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/ActivityLog.cs)。
- U14：[工坊验证客户端](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/Function/WorkshopVerificationClient.cs)、[联机接口](https://github.com/LorisYounger/VPet/blob/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows.Interface/MutiPlayer)。
- A1：[AppModel](../Sources/iPetMac/AppModel.swift)、[PetWindow](../Sources/iPetMac/PetWindow.swift)、[ControlsView](../Sources/iPetMac/ControlsView.swift)。
- A2：[PetEngine](../Sources/PetCore/PetEngine.swift)、[PetState](../Sources/PetCore/PetState.swift)、[PetSaveStore](../Sources/PetCore/PetSaveStore.swift)；具体保留公式见 [BEHAVIOR.md](BEHAVIOR.md)。
- A3：[PetScene](../Sources/PetRendering/PetScene.swift)、[Manifest](../Sources/PetRendering/Manifest.swift)。
- A4：[资源转换器](../scripts/convert_assets.py)、[玩法目录转换](../scripts/convert_gameplay.py)，生成清单不等同完整LPS解析器。
- A5：[图标记录](../Design/README.md)、[来源](../ATTRIBUTION.md)、[素材授权](../ANIMATION_LICENSE.md)。
- A6：[Package.swift](../Package.swift)、[验证脚本](../scripts/verify.sh)。
- A7：[构建脚本](../scripts/build.sh)、[交接与验证边界](HANDOFF.md)。

本表覆盖当前已识别的原版能力家族，上游目录内更细的选项、插件和第三方内容不声称穷尽。每阶段规格需扩展逐场景清单，新增发现必须分配状态、源码入口和阶段；未复核的能力保持待验证，不以编译成功代替行为等价。

阶段3A首批依据与适配边界见[specs/PHASE-3A.md](specs/PHASE-3A.md)：普通待机新增两种，原始PNG帧名按末尾数字解析毫秒时长；短时打盹不改养成resting状态。

阶段3B已接入6种升降过渡组合与18套额外阶段图层变体；共77组合、2493唯一PNG、约317.6MiB（物品图片另计）。只扩充Default/抚摸/Boring/Squat变体，未宣称活动、移动、食物全部变体完成。资源清单v3，存档仍v2；详见[specs/PHASE-3B.md](specs/PHASE-3B.md)。

阶段3C已接入300ms区域长按提起及同抚摸循环续一次；按住不刷收益，抚摸按点击逐次结算。轻点/拖动隔离输入检查通过，真实静止长按另待最终验收。下一步本地气泡/文本，动态提起变体和按压配置仍为缺口，详见[specs/PHASE-3C.md](specs/PHASE-3C.md)。

## 阶段3D文本与气泡

已接入ClickText/v2/v3和LowText，625条点击、46条提醒，按原时段、模式、标签、活动/睡眠及属性范围筛选。原文件一条多行文本损坏，连同孤立尾部明确排除；160条Tags拼写按原Tag序列化默认all处理并诊断，未擅自修正原逻辑。转换目录v1独立于动画v3与存档v2。源码见[PetDialogue](../Sources/PetCore/PetDialogue.swift)、[转换工具](../scripts/convert_dialogue.py)、[气泡窗口](../Sources/iPetMac/PetSpeechWindow.swift)，规格见[PHASE-3D](specs/PHASE-3D.md)。

点击严格超过20秒后可结算文本属性/金币，按原即时/缓释规则；睡眠文本不唤醒。自动提醒只在空闲、可见且没有气泡时触发，不自动购买、不给休息/活动插入饥渴动作。SelectText、语音、Say动画、消息队列/流式显示尚未迁移；未做Windows同条件实机对照。

## 阶段3E随宠工具栏

原版ToolBar提供状态与工作/学习/娱乐等入口，WorkTimer显示活动时间、收益及停止反馈。iPet使用独立非激活小面板，状态/活动/商店/背包/休息/对话快捷入口和活动进度、剩余分钟、已获收益、暂停/继续/结束已接入；菜单栏或设置页启用，默认关闭。现有活动页与工具栏共用只读[ActivityFeedback](../Sources/PetCore/ActivityFeedback.swift)，操作复用原核心事务，不重复结算奖励。状态为“部分实现”：原多级菜单、鼠标自动隐藏、小标、DIY入口、完整计时/统计仍缺，详见[规格](specs/PHASE-3E.md)与[窗口实现](../Sources/iPetMac/PetToolbarWindow.swift)。

下方优先并按可见屏幕约束，拖动期间暂隐藏；气泡参照桌宠和工具栏的联合范围定位。新增toolbarEnabled偏好，不改JSON v2、动画v3或文本v1；物理焦点、睡眠、多屏和长期运行仍需最终验收。
