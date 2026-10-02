# Windows 原版与 iPet 的持续差异矩阵

原版基线：`1a06c5981330564bab05a098d2d7969a4b119dd3`；iPet 当前基线：v0.2.0，已推进至阶段3W；部分实机验收已记录，压力测试按用户要求留到功能完善后。原版功能依据上游固定基线源码，不将第三方插件功能算作内置功能；当前行为依据 Apple 源码和已记录验证。后续每次迁移更新本表、行为说明和交接记录。源码入口编号在文末，阶段对应 [ROADMAP.md](ROADMAP.md)。

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
| 动作规模与随机池 | 完整角色动画、变体和随机互动池 | 147个动作/Graph/状态组合、4248个唯一PNG；Default/抚摸/Boring/Squat按阶段抽取变体，其余保留子集 | 缩小资源包和首版范围；组合数不是完整活动种数 | 部分实现 | U3、U4、U8 → A3、A4 | 3 |
| 触摸/提起/行走 | 原配置触摸区及动作逻辑 | 映射头/身体区域，拖动暂停自主移动，基础左右走 | 平台输入适配；触摸区使用500逻辑画布 | 已适配 | U4、U8 → A1、A3 | 1、3 |
| 爬墙/边缘隐藏/移动区域 | 原版边缘检查、移动区与相关动作 | 水平安全边界、左右/顶部爬墙、斜向下落、侧挂/探头/回正；原内置移动池和双轴衔接已接入，跨屏策略仍缺 | 窗口部分越屏定位和安全回正；完整移动池尚缺 | 部分实现 | U3、U4、U6 → A1 | 3 |
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
| 性能和稳定性 | 原版实现不能单凭源码推断性能 | 缓存估算48MiB、按帧加载；v0.1历史120秒观察；当前共81个Swift测试，短时实机记录不替代长期观察；两小时留到功能完善后 | 无同条件Windows对照，不能声称更省资源/稳定 | 待验证 | U8 → A3、A7 | 1 |

## 2026-10-02 逐功能复核补充

当前缺口与建议顺序详见 [REMAINING-FEATURES.md](REMAINING-FEATURES.md)。以下将原先“动作/界面/其余功能”的大项拆开，避免已实现经济闭环掩盖体验缺口。

| 能力 | 原版行为 | iPet 当前行为 | 差异原因 | 状态 | 源码依据（原版 → iPet） | 阶段 |
| --- | --- | --- | --- | --- | --- | --- |
| 自主互动调度 | 移动、待机、特殊待机、睡眠及扩展随机池，概率受InteractionCycle/CountNomal影响 | 15秒抽选，区间max(20,200-默认动画循环次数)；状态步行/爬行、Boring/Squat、短时打盹；忙碌时不触发 | 抽选分支已接入；特殊待机/扩展池、活动中互动及原随机循环退出尚缺 | 部分实现 | U3 → A1 | 3 |
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

## 阶段3F水平动作与边缘检查

新增快走、慢走、左右爬行与阶段变体，共87组合/2672唯一PNG/338.7MiB。依据vup.lps水平move与GraphHelper.Move：普通14、快走20、慢走/爬行10逻辑像素每125ms；本版按size/500换算并平滑到帧间隔。起步方向距离不足200逻辑像素时尝试反方向，均不足不启动；继续接近100逻辑像素边界停止，位移仅循环阶段，Ill仍禁自主移动。几何和Graph阶段验证通过，不等于全部随机场景实机确认。源码见[PetWalkPlan](../Sources/PetRendering/PetWalkPlan.swift)、[PetScene](../Sources/PetRendering/PetScene.swift)、[转换器](../scripts/convert_assets.py)，详见[规格](specs/PHASE-3F.md)。

状态“部分实现”：步行/爬行各半选择为适配，未还原原全部ModeType候选抽池、Distance随机循环退出、兼容动作衔接；仍为五秒上限并可因边界提前停止。爬墙、侧边隐藏、跨屏与自定移动范围尚缺，不能据水平边缘检查宣称完整边缘行为。保存v2/清单v3/文本v1不变，压力测试未启动。

## 阶段3G移动循环与水平衔接

已移除阶段3F五秒上限，按实际B循环次数执行原Next(walklength++)<Distance：首轮已接受，Distance7普通走、5快/慢走、8爬行；失败时40%尝试兼容子集。子集保持水平同方向、按200触发距离筛选，包含当前动作；无法衔接则走结束阶段，不追加一轮循环。动作替换使旧动画回调/帧时间失效。源码见[PetMoveCycles](../Sources/PetCore/PetMoveCycles.swift)、[PetWalkPlan](../Sources/PetRendering/PetWalkPlan.swift)及PetScene/AppModel，详见[规格](specs/PHASE-3G.md)。

仍为“部分实现”：原完整候选池含垂直/斜向动作，本版只有状态步行/爬行；Poor普通走候选及StopMoving自动回正尚缺。100安全边缘即时停止时水平子集均不满足200触发距离，不做无意义反转；不保证.NET相同随机种子序列。初始步行/爬行各半仍是适配，爬墙、侧边隐藏/跨屏和最终实机/长期门槛继续保留。

## 阶段3H左右爬墙

新增左右墙上下移动，左定位145/右185逻辑单位、边缘<=100、上下起步>=200、继续到100安全线，SpeedY10/125ms按500画布缩放并反转macOS轴向；Distance7沿原循环退出。开始结束后才贴边并移动，部分窗口可越屏；结束、人工取消、隐藏/睡眠/大小/屏幕变化和退出回正，拖动期间不瞬移、松开恢复。移动范围和工具栏/气泡锁定开始时屏幕，屏幕变化重新恢复；保存位置使用安全坐标。源码见[PetClimbPlan](../Sources/PetRendering/PetClimbPlan.swift)与AppModel，规格见[PHASE-3H](specs/PHASE-3H.md)。

总93组合/2742唯一PNG/350.2MiB，仍为部分实现：起始边缘50%爬墙分支是适配；水平边界40%尝试上下，爬墙循环退出40%尝试同侧同向自身子集。顶部爬行、下落、SideHide、跨屏和原完整候选池尚未实现。不同倍率/相邻屏幕裁剪、实际输入与恢复需最终实机确认，不能把几何或资源测试作为全部实机验收。

## 阶段3I侧挂与点击恢复

原版MainLogic.MoveSideHideCheck以越边超过50×缩放触发，vup.lps side定位219/281；Main.xaml.cs.Load_2_TouchEvent在点击时回正并直接播放Main C段。当前在拖动松开检查左右Main，开始—持续循环，点击可见角色优先回正再播放结束段，取消/睡眠/屏幕变化等恢复可见位置，重启只加载安全坐标。资源99组合/2902唯一PNG/372.1MiB（物品另计），依据当前PetSideHidePlan、PetScene、AppModel、convert_assets.py，详见[规格](specs/PHASE-3I.md)。

状态“部分实现”，阶段3：尚未迁移鼠标进入/离开Rise、原所有MoveEnd入口、自动跨屏和移动区域；纵向越界用macOS visibleFrame夹紧替代原底部额外100偏移。存在相邻屏幕裁剪与真实点击恢复验证缺口。养成、保存v2/动画v3/文本v1不变，不新增离线扣减，不把单元测试作为实机证明。

## 阶段3J侧挂悬停探头

原版Main.xaml.cs.MainGrid_MouseEnter/Leave：Main进入播放Rise开始/循环，离开播放Rise结束后返回Main循环；点击Main/Rise均回正并播放Main结束。当前PetScene保留Main资源作为恢复目标，AppModel仅侧挂时检测窗口范围进入/离开，点击使用Main C而非Rise C；缺Rise保留Main、解码失败通知恢复，详见[规格](specs/PHASE-3J.md)。新增左右Rise各三状态，资源105组合/2996唯一PNG/385.9MiB，仍属阶段3“部分实现”。

原MainGrid范围映射为macOS窗口画布范围，与alpha点击穿透独立；按键/拖动期间暂停悬停切换。快速重新进入打断离开并重播Rise开始，是减少输入延迟的适配（原Rise离开完成前不重新进入）。原全部MoveEnd入口、顶部下落/跨屏未迁移，真实鼠标/多屏/睡眠尚待最终验证，不把渲染测试当实机验收。

## 阶段3K顶部爬行与下落

原vup.lps四条climb.top/fall及GraphHelper.Move参数：顶Locate150、速度8/125ms、Distance10；fall水平14/垂直10每125ms、Distance7。当前PetClimbPlan扩展top/fall，macOS翻转Y轴，按原100触发顶部距离、200起步侧/底距离及100停止边界；Happy/Nomal/Poor允许，Ill拒绝，开始动画完成后位移。窗口部分越顶，结束/取消/保存沿已有安全回正；资源117组合/3251唯一PNG/414.5MiB。详见[规格](specs/PHASE-3K.md)，当前状态仍为阶段3“部分实现”。

斜向到边界同一比例截停是安全适配；初始仍沿50%特殊移动分支，扩充wall/top/fall候选，循环退出仍只尝试同类型同向自身，原完整加权兼容池另批迁移。所有Graph在climb渲染动作族内，不代表养成新增动作或存档升级。真实顶部裁剪、跨屏输入与睡眠/压力未验，未实现原全部MoveEnd入口和移动范围设置。

## 阶段3L完整内置移动池与衔接

原MainDisplay.DisplayToMove从随机排列中取首个Triggered，等价于从有效条目均匀选择；当前PetMovementChoice汇集全部16条内置move规则（14个Graph，左右墙各上/下独立），移除初始50%特殊分支与步行/爬行各半。补回Poor普通walk（14/125ms，Distance7）与slow同时作为候选，Happy只有fast/crawl，Nomal普通/crawl。GetCompatibilityMove按双方非零X/Y同向+1、反向-1，总分>=0且Triggered允许，保留自身，循环退出及边界40%尝试全池。

当前PetWalkPlan.originalCandidates/PetClimbPlan.traversalCandidates与AppModel统一选择，顶部部分越屏可向下墙/横走/下落衔接，不在衔接前瞬移回正；结束/取消才回正，范围固定起始屏幕。详见[规格](specs/PHASE-3L.md)，仍阶段3“部分实现”：调度节奏、随机源序列、visibleFrame和100安全截停是现有适配；原全部MoveEnd侧挂、自定义范围和跨屏尚未迁移，真实剪裁/焦点、多屏/睡眠与压力仍待验。资源117组合/3251PNG/414.5MiB与保存版本保持。

## 阶段3M动态提起与放下

原MainDisplay.DisplayRaising依次播放三次Raised_Dynamic Single后进入Raised_Static A/B，Main.xaml.cs.MouseMove位移绝对值和>20且计数>=1时重置；松手侧挂优先，否则Static C。当前PetScene.beginRaise/updateRaiseMotion/finishRaise与PetWindow拖动位移回调保留该顺序、20逻辑阈值及直接结束，动态Single映射为非循环loop并按目录选择变体；资源121组合/3309PNG/422.6MiB。详见[规格](specs/PHASE-3M.md)，仍阶段3“部分实现”。

未迁移原RaisePoint瞬移定位、捏脸pinch及所有特殊提起Graph名字的关联；保留已验收的光标相对拖动策略。动态图缺失回静态并诊断，新动作清理计数；松手任意动态阶段直接Static结束。动作阶段测试不是物理鼠标验收，真实不同倍率/静止长按、多屏/睡眠/压力仍待最终验证；养成与保存版本不变。

## 阶段3N长按捏脸

依据Windows/MainWindow.cs.DisplayPinch/DisplayPinch_loop及初始化TouchEvent.Insert(0)，原pinch长按区域(149,128,56,59)先于提起，仅有当前状态A才响应；首次与仍按住的每个B结束时Strength>=10、Feeling<100消耗2体力增加1心情。PetCore.touchPinch保留公式/边界且不改变休息/活动，PetWindow长按优先消费，PetScene循环回调按持有状态应用效果；短按仍抚摸，移动仍能转拖动，松手进入结束后恢复基础。详见[规格](specs/PHASE-3N.md)。资源124组合/3400PNG/436.5MiB，阶段3状态“部分实现”。

当前侧挂时不接受pinch，保留找回/拖动优先；动画循环保持启动时的显示状态，不在每次数值变化后切换状态贴图。原头/身体宿主统计事件、好友联动、特殊Graph关联和RaisePoint定位仍缺。当前只有三状态素材，Ill缺A拒绝，不以正常动画替代允许区域。核心效果是实际移植，但物理长按/穿透/焦点、多屏/睡眠及压力尚未验；保存版本无变化。

## 阶段3O普通待机池和概率循环

原DisplayToIdel选有效Idel名字，再查A或Single；DisplayBLoopingToNomal以Next(++looptimes)>duration退出，GetDuration默认10，boring/squat20。当前转换9个可触发Graph：aside/boring/bubbles/happy_like520/meow/meowlook/squat/tennis/yawning；amusement_B只有B，不独立触发。Single播放一次，A/B/C按原概率循环。GraphCore.FindGraphs逐阶段非Ill相邻状态回退已适配，Squat开心缺B使用Nomal B，未标状态的Bubbles按Nomal、路径happy_like520按Happy。

PetIdleCycles、PetManifest.fidgetCandidates/resolveFidget、PetScene和AppModel已接入，资源141组合/4132PNG/540.8MiB（物品另计）；纹理缓存仍按需48MiB限制，不预加载全包。清单v3新增可选idleLoopLimit、旧清单仍可加载，保存v2/文本v1不变。详见[规格](specs/PHASE-3O.md)，阶段3仍“部分实现”：StateONE/StateTWO与扩展池、打盹20秒固定上限未迁移；阶段内不重新抽变体，.NET随机序列和原调度节奏仍不同。真实显示、资源常驻内存和长期压力未验。

## 阶段3P两阶段特殊待机与打盹

原随机分支6进入StateONE；MainDisplay.StateONEing以duration10循环退出，Next(2+CountNomal)==0进入TWO并递增CountNomal，TWO结束后C返回ONE B，后续进入TWO概率随次数下降。当前PetSpecialIdle与PetScene完整阶段链已接入，人工结束/新动作清理内部返回，缺当前状态ONE回普通待机，Ill不借非Ill。打盹使用sleep duration20概率循环，取消固定20秒定时器，状态变化不按人工休息路径提前重置打盹；人工休息仍无限循环。

资源147组合/4248PNG/555.1MiB（物品另计），新增6个特殊状态组合，保存v2/清单v3/文本v1不变；可选idleLoopLimit接受specialIdle/sleep且旧清单用默认值。详见[规格](specs/PHASE-3P.md)，阶段3仍“部分实现”：展示保留开始时状态、逐循环变体重抽/扩展随机插件与活动中互动未迁移；打盹不新增state.resting或补算离线时间，自动睡眠养成效果需后续全场景对照。真实两阶段观感、输入/多屏/睡眠和压力待验。

## 阶段3Q循环内状态与变体

原GraphCore.FindGraph/FindGraphs每次Display按当前Mode和阶段重新抽图。当前Manifest.resolvePlayback逐动作/Graph/阶段查询，Timeline.rebind保留阶段、循环/人工结束/续一次标志及余量，Scene在阶段变化/B边界重新选当前变体，不重播A；AppModel排队最新显示状态，活动和人工休息状态变化不再重开开始段。动态提起下一轮也重查原素材，捏脸循环效果产生的新状态立即排队；无Ill资源请求结束，最终回最新状态待机，不借非Ill延长动作。

详见[规格](specs/PHASE-3Q.md)，阶段3仍“部分实现”。资源147组合/4248PNG/555.1MiB、保存v2/清单v3/文本v1不变；250ms内跨多个短循环只渲染最后可见结果，余量夹到新时长内，为安全时间轴适配，不承诺.NET随机序列或逐帧一致。原全部MoveEnd侧挂、自动睡眠养成对照、扩展池和完整配置仍缺；真实状态变化观感、焦点/输入、多屏/睡眠与压力待验。

自动打盹养成核对：基线MainDisplay.cs的DisplaySleep(false)只播A及概率B循环，不设置WorkingState；DisplaySleep(true)才设置Sleep并无限循环。iPet随机playDoze不设置resting，人工休息设置resting，符合该区分；本项为源码与模型核对，未增加实机验收证据。

阶段3R补齐正常移动C结束后的侧挂入口：按原50逻辑像素阈值与Main定位，先尝试侧挂再安全回正，正常结束接管不再调用通用恢复；解码失败、已取消、隐藏/睡眠和人工输入不接管。原RePositionActive/CheckPosition和AutoChangeWindow仍为平台适配缺口，不能把入口补齐视为完整移动系统还原，真实显示/输入尚待验。源码：原Main.xaml.cs Event_MoveEnd、GraphHelper.StopMoving → PetScene.onMovementCompleted、AppModel.beginSideHide。

阶段3S按winInventory.UpdateList接入背包名称搜索/分类/收藏、默认/名称/数量/单价升降序与全库存价值汇总；未知物品保留并标记未计价。状态仍部分实现：原详情数量/批量使用尚缺，收藏从原物品Star适配为本机偏好，未纳入跨机保存；排序文化与大小写搜索是原生适配。依据：PetInventoryQuery、InventoryView和AppModel.toggleFavorite；单件养成/经济规则不变，真实UI尚待验。

阶段3T接入背包数量输入/步进、按库存夹取、逐件批量使用及停止剩余，重复衰减/库存/保存结果有固定时钟对照。原winInventory.UseItem与Food UseAction → PetEngine.useItems、AppModel.useInventory、InventoryUseControls；主线程分批32件及批内只展示最后进食是平台响应性适配，非原动画请求队列完全一致。每批保存，保存失败停止、只读模式拒绝开始；收藏随档迁移和真实批量/取消/睡眠验收仍缺，存档v2不变。

阶段3U将硬编码互动周期改为30...1000可调/默认200，本机偏好保存；原MainLogic max(20,InteractionCycle-CountNomal)范围沿用，修改不清空计数或抢先采样。依据winGameSetting.InteractionSlider、Setting.InteractionCycle → PetAutonomy.setInteractionCycle、AppModel/ControlsView。仍15秒采样/基础待机才触发，活动中互动权重和扩展池未迁移；养成关闭/固定状态仍缺，真实频率观感待验。

阶段3V接入养成开关与关闭时固定呈现状态，时钟重建且恢复不补算；关闭退出活动/休息、抚摸仅反馈。原FunctionSpend/NoFunctionMOD、CalFunctionBox、winBetterBuy与库存Food UseAction分别核对：购买即用仅动画，库存使用仍生效；原生买入背包仍扣款、关闭拒绝新活动为适配，不宣称所有禁用模式入口完全一致。固定模式影响动画/移动/文本筛选但不改数字属性或JSON。依据PetEngine.configureSimulation/presentationMood、PetDialogue可选模式、PetScene.restoreBase与AppModel/ControlsView/ShopView；保存v2不变，真实切换/恢复观感待验。

阶段3W新增置顶/普通层级、角色全部穿透、不透明度0.05...1及菜单/设置恢复默认；正常模式沿alpha自动穿透，独立工具栏仍可操作，辅助面板层级跟随且不降低可读性。原winGameSetting TopMost/HitThrough/Opacity → PetWindowBehavior、AppModel.applyWindowPreferences与原生面板；OpacityMain/OpacityHitThrough动态组合、全屏和真实焦点/遮挡/穿透仍未完成，部分实现，保存v2不变。
