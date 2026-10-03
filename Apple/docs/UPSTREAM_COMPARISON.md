# Windows 原版与 iPet 的持续差异矩阵

原版基线：`1a06c5981330564bab05a098d2d7969a4b119dd3`；iPet 当前基线：v0.2.0，已完成阶段5开发/研究交接，2026-10-03恢复阶段3Z提起锚点迁移（真实输入待验）；部分实机验收已记录，压力测试按用户要求留到功能完善后。原版功能依据上游固定基线源码，不将第三方插件功能算作内置功能；当前行为依据 Apple 源码和已记录验证。后续每次迁移更新本表、行为说明和交接记录。源码入口编号在文末，阶段对应 [ROADMAP.md](ROADMAP.md)。

状态定义：**已保留**为纳入范围的原规则已移植；**已适配**为平台或产品行为有明确变化；**部分实现**为有可用子集；**尚未迁移**为没有原生实现；**需要平台替代**为原机制不能直接复用；**待验证**为代码或构建证据不足以完成验收。状态指本行能力，不代表整个类别完成。

| 能力 | 原版行为 | iPet 当前行为 | 差异原因 | 状态 | 源码依据（原版 → iPet） | 阶段 |
| --- | --- | --- | --- | --- | --- | --- |
| 平台与窗口 | C#/.NET/WPF，Win32 桌面窗口 | Swift6/AppKit/SpriteKit/SwiftUI，macOS14+ | 原生重建窗口与界面 | 已适配 | U1 → A1 | 0、1 |
| 穿透与焦点 | WPF/Win32 输入与窗口设置 | 30Hz 当前帧 alpha 穿透；桌宠不能成为主键盘窗口 | 平台机制不同；本机拖动、穿透与焦点已有记录，快速点击及更多设备仍待验 | 部分实现 | U1 → A1 | 1 |
| 显示器与睡眠 | Windows 移动边界、定时器和保存生命周期 | 屏幕变化重新约束位置；睡眠保存、暂停，恢复重置计时基准 | AppKit 生命周期适配，实机检查未完整完成 | 待验证 | U1、U3、U7 → A1 | 1 |
| 基础状态属性 | 桌面GameSave_VPet等级/突破影响体力和心情上限，健康0…100、好感独立上限 | PetState已接桌面剩余经验、突破和动态上限；突破暂存超当前上限属性，下次变化截断 | 已按实际桌面类纠偏，旧JSON升级保留原件 | 部分实现 | U2、U7、U11 → A2、PetDesktopGrowth | 2、4 |
| 状态判断 | 桌面CalMode按Feeling/FeelingMax判断；健康修正源码采用比例>=80 | 已接桌面CalMode、动态比例判断，保留源码比例>=80条件 | 采用实际桌面保存类；源码怪异比例条件不擅自修正 | 部分实现 | U2、U11 → A2、PetDesktopGrowth | 2 |
| 日常/休息推进 | FunctionSpend 按活动分支推进 | 移植默认/休息/活动分支，15秒逻辑步长及活动时长推进 | 活动范围缩减 | 部分实现 | U3 → A2 | 2 |
| 离线时间 | 已查定时器和主加载路径未见离线养成补算 | 不新增退出/睡眠扣减；长调度间隔不追补 | 保守移植和平台生命周期适配；不是全插件路径审计 | 已适配 | U3、U7 → A1、A2 | 1、2 |
| 抚摸与投喂公式 | 抚摸体力消耗/心情恢复；EatFood 一半即时、一半缓释；StoreTake 尾数处理 | 保留纳入规则，包括原边界和运算顺序 | 子规则对照，不等于完整商店 | 已保留 | U2、U4 → A2 | 2 |
| 食物参数与图片 | 数据定义食物属性、价格、类型、图片 | 118项原物品、原PNG图片、七种类别与重复食用衰减 | 恢复内置物品；限时4项排除 | 已适配 | U5、U6 → A1、A2、A3 | 2、3 |
| 工作/学习/娱乐 | Work 类型、效率、状态消耗、金钱或经验收益和计时窗口 | 13内置活动、原默认自动平衡、效率/收益/完成奖金及暂停恢复、倍率/套餐/日程 | 仅内置活动，原UI计时器改为核心单一计时 | 已适配 | U3、U6 → A2 | 2 |
| 商店/库存/物品 | 购买、库存、不同类别物品与使用统计 | 购买即用/入包、库存数量与使用；已有本地购买/使用统计，平台/联网键未完整迁移 | 仅内置目录，不支持第三方扩展 | 部分实现 | U5、U6、U7 → A1、A2 | 2 |
| 疾病与药品 | Ill 状态、活动中止和药品消费 | Ill判断、活动状态失败中止、原药品及免费应急药代价 | 首版恢复途径简化 | 部分实现 | U2、U3、U5、U7 → A2 | 2 |
| 经验/好感与金钱 | 桌面剩余经验+等级/突破、负经验不掉级，好感上限每升级+10，新建金币100 | 剩余经验/等级突破、负经验不降级、独立好感上限、新建100；旧金币原值保留，升级动画尚缺 | 已复核桌面类与Core差异，存档迁移需保留原件 | 部分实现 | U2、U3、U11 → A2、PetDesktopGrowth | 2、4 |
| 动画帧与阶段 | 图层、开始/循环/结束、状态动画及变体 | 保留选用帧的时长、自然排序、阶段与食物图层运动 | 首版按动作选取资源 | 部分实现 | U4、U8 → A3、A4 | 3 |
| 动作规模与随机池 | 完整角色动画、变体和随机互动池 | 151个动作/Graph/状态组合、4393个唯一PNG；Default/抚摸/Boring/Squat按阶段抽取变体，其余保留子集 | 缩小资源包和首版范围；组合数不是完整活动种数 | 部分实现 | U3、U4、U8 → A3、A4 | 3 |
| 触摸/提起/行走 | 原配置触摸区及动作逻辑 | 映射头/身体区域、四状态RaisePoint提起定位，拖动暂停自主移动；完整内置移动候选已接入 | 平台输入适配；触摸区使用500逻辑画布 | 已适配 | U4、U8 → A1、A3 | 1、3 |
| 爬墙/边缘隐藏/移动区域 | 原版边缘检查、移动区与相关动作 | 水平安全边界、左右/顶部爬墙、斜向下落、侧挂/探头/回正；原内置移动池和双轴衔接已接入，跨屏策略仍缺 | 窗口部分越屏定位和安全回正；原生主屏/固定矩形已适配，自动换屏按边缘入口已适配，25%回正和主动放置保护已适配，实机跨屏仍缺 | 部分实现 | U3、U4、U6 → A1 | 3 |
| 动作打断/回退 | 原 Graph 调度与状态切换 | 新时间线替换；缺状态按清单回退并诊断 | SpriteKit 调度及资源子集适配 | 已适配 | U3、U8 → A3 | 3 |
| 面板/工具栏/说话栏 | WPF设置、工具栏、对话及各功能窗口 | 十个中文原生页面、可选随宠工具栏/进度、本地气泡和菜单栏；未还原全部WPF操作 | WPF不能原样作为SwiftUI界面运行 | 部分实现 | U1、U6、U9 → A1 | 3 |
| 原作资源与新图标 | 原图标、角色、LPS配置与PNG | 保留原目录；新像素风参考图标，LPS构建前转JSON；运行时不依赖LPS | 原生资源目录与资源子集 | 已适配 | U8 → A4、A5 | 0、3 |
| 多角色与数据MOD | PetLoader/CoreMOD加载角色、食物、文本等 | 仅内置萝莉斯子集；无第三方数据加载接口 | 转换工具不是通用MOD兼容器 | 尚未迁移 | U5、U8、U10 → A4 | 4 |
| 主题/文本/本地化 | Theme、MOD文本及本地化资源 | 固定简体中文原生界面 | 需要新数据模型和界面主题适配 | 尚未迁移 | U5、U9、U10 → A1 | 4 |
| 本地存档安全 | LPS养成/设置及多存档管理 | Codable JSON v9，v1～v8升级原件保留、原子保存、损坏恢复和未来版本阻写 | 独立格式；历史VPetApple目录保留 | 已适配 | U7、U11 → A2 | 2、4 |
| 旧LPS存档导入 | 原版读取自己的LPS格式 | 已有结构/宠物候选/hash校验和库存完整参数只读预览；库存参数原生持久化已接入，统计已提供已核对数值只读子集；Data及预览UI/确认导入尚缺，不写原档 | 已有真实库合成字段样例，整档映射与明确拒绝报告仍需完善 | 部分实现 | U7、U11 → A2 | 4 |
| C#代码插件 | CLR程序集加载、MainPlugin和原接口 | 不兼容C# ABI、事件或WPF插件界面 | Swift不能直接执行原插件；与数据MOD任务不同 | 需要平台替代 | U10、U12 → A1、A2 | 5研究 |
| 排程/统计/活动日志 | ScheduleTask、Statistics、ActivityLog | 有本地购买/使用、活动时间/收益和最近200条结束记录；日程循环与原生页面、本地eval陪伴时长/连续日/完成率已接入，其余平台/联网统计键未完整迁移 | 独立结构化本地统计，旧历史不估算 | 部分实现 | U7、U13 → A1、A2 | 5 |
| 图库及其余功能 | Gallery、Console、保存管理等独立功能 | 图库和完整动画调试未迁移；已有诊断报告与本机存档导出恢复 | 六个ZIP型zlps及解锁/授权已研究，当前不打包；见生态研究 | 部分实现 | U6、U7 → A1 | 5研究 |
| Steam/云存档/工坊 | SteamRemoteStorage、工坊和验证客户端 | 无接入、云同步或订阅更新 | SDK/身份/工坊内容与云冲突已形成独立研究结论，接口未实现 | 需要平台替代 | U7、U10、U14 → A1 | 5研究 |
| 联机/对话生态 | MutiPlayer接口；TalkBox及插件可扩展对话 | 无联机、AI服务或网络对话 | 不将插件能力视为内置AI已移植 | 尚未迁移 | U9、U12、U14 → A1 | 5研究 |
| iOS | 本基线Windows工程，无原生iOS产品 | PetCore/PetRendering Simulator编译通过，无iOS界面/真机证据 | 移动应用内养宠另做前后台适配 | 待验证 | U1 → A6 | 6 |
| 发行与许可证 | 原README渠道及Apache代码/独立素材授权 | GitHub源码、自用ad-hoc构建；原署名/许可随包，无签名公证发行包 | 发行准备未完成；素材授权独立 | 部分实现 | 原README、LICENSE → A5、A7 | 0、6 |
| 性能和稳定性 | 原版实现不能单凭源码推断性能 | 缓存估算48MiB、按帧加载；v0.1历史120秒观察；当前共372个Swift测试，短时实机记录不替代长期观察；两小时留到功能完善后 | 无同条件Windows对照，不能声称更省资源/稳定 | 待验证 | U8 → A3、A7 | 1 |

## 2026-10-02 逐功能复核补充

当前缺口与建议顺序详见 [REMAINING-FEATURES.md](REMAINING-FEATURES.md)。以下将原先“动作/界面/其余功能”的大项拆开，避免已实现经济闭环掩盖体验缺口。

| 能力 | 原版行为 | iPet 当前行为 | 差异原因 | 状态 | 源码依据（原版 → iPet） | 阶段 |
| --- | --- | --- | --- | --- | --- | --- |
| 自主互动调度 | 移动、待机、特殊待机、睡眠及扩展随机池，概率受InteractionCycle/CountNomal影响 | 15秒抽选；空闲max(20,周期-循环次数)，活动区间翻倍再加20；16种移动、9种待机、StateONE/TWO及打盹，活动中视觉随机不改会话 | 抽选与原生动作衔接已适配；第三方扩展池与实机边界仍缺 | 部分实现 | U3 → A1 | 3 |
| 状态过渡动画 | PlaySwitchAnimat沿状态顺序播放Switch_Up/Down | 在默认/过渡动作中逐级播放6种过渡组合；忙碌时不插入；支持取消与新目标 | 原顺序移植，缺帧时诊断/退到目标状态，完整实机待验 | 已适配 | U3 → A1、A3、A4 | 3 |
| 按压/连续抚摸 | 长按阈值、触摸动作匹配；同触摸动作可延续循环 | 300ms原状态区域长按提起；位移超过4点拖动；同抚摸开始不重播、循环续一次 | 当前输入状态机简化；已补四状态RaisePoint定位和缩放，特殊提起关联及真实输入仍缺 | 部分实现 | U4、Core/Display/Main.xaml.cs → A1 | 3 |
| 角色文本反馈 | ClickText、LowText、SelectText及MessageBar/TalkBox | 671条点击/提醒文案及189条选择文本；独立五项话题池、十分钟刷新/选择加五分钟、后续话题/原属性效果/事件计数；非激活原生气泡 | 原文本规则已迁移，自动提醒限空闲；已接入逐字/按标点停留/淡出，已接入四组待机Say表情与A/B/C衔接；语音、完整消息队列及原hostsay持久日志仍缺 | 部分实现 | U3、U5、U9、U10 → A1 | 3、4 |
| 语音播放接口 | Main.PlayVoice、音量及播放完成/失败处理 | 无音频播放层 | 需原生接口与可分发语音资源确认；不代表内置角色一定配有语音 | 尚未迁移 | Core/Display/Main.xaml.cs → A1 | 3、5 |
| 库存便捷操作 | 搜索、类别、名称/数量/价格排序、收藏、数量选择使用、总价值 | 名称搜索、类别/收藏筛选、四种排序、全部已知库存价值、数量分批使用与取消 | 收藏为本机ID偏好；分批处理为响应性适配，未知物品保留 | 部分实现 | U6 winInventory → A1 | 2、3 |
| 养成/移动设置 | 养成开关/固定显示状态、互动周期、智能移动、自定移动范围等 | 养成开关、固定显示状态、互动周期、自主移动开关、大小、隐藏和重置 | 智能移动交互超时已接入；自定范围仍缺；开关时停止活动为原生适配 | 部分实现 | U6 winGameSetting → A1 | 3 |
| 窗口显示设置 | 顶层/穿透切换、透明度、消息框位置、快捷小标等 | 可切换置顶、全穿透、固定透明度；默认按角色alpha穿透 | 动态透明度、全屏适配、消息框位置等仍缺 | 部分实现 | U1、U6 → A1 | 3 |
| 存档管理界面 | 查看/选择存档、多开档、新建/重开等 | 单JSON v9、版本原件备份、显式导出与确认恢复、打开存档目录 | 多档列表/新建与Windows LPS导入未迁移 | 部分实现 | U6、U7、U11 → A1、A2 | 4、5 |
| 活动倍率与排程 | Work.Double与平衡公式；套餐/抽成/自动续费后循环执行 | 倍率需求、等级与收益重算、会话/历史保存；14项套餐签署/退款/到期检查续费 | 日程队列/执行/存档与操作界面已接入，实机待验；基线抽成只保存/展示，不另加无来源扣除；0授权拒绝负价续费 | 部分实现 | ExtensionFunction.Double/FixOverLoad、ScheduleTask → PetActivityMultiplier、PetEngine、ActivityView | 2、5 |
| 活动收藏与检索 | work_star按名称保存，收藏类别/菜单及任务排程 | 名称搜索、类别/收藏筛选、默认/名称/时长/等级升降序，按ID收藏 | 原生检索扩展；本机偏好不随档，日程与DIY链接/本机目标已接入，Windows按键仍缺 | 部分实现 | U6 winWorkMenu → PetActivityQuery、ActivityView、AppModel | 3、5 |
| 自定义菜单链接/启动目标 | DIY名称/内容、删除/首尾排序、LoadDIY/RunDIY | 原生快捷页、菜单栏与随宠Menu；打开系统URL处理器及本机应用/文件/文件夹，独立配置v2与备份，保留v1升级原件 | macOS NSWorkspace代替Process.Start，原LPS DIY未导入 | 部分实现 | U6 MainWindow/DIYViewer → PetShortcuts、AppModel、ShortcutView、PetToolbarWindow | 5 |
| Windows按键序列 | SendKeys键语法、录制及发送到应用 | Windows键记录保留不可执行；原生组合键录制/文本步骤/显式投递已接入，实机待验 | 已提供独立macOS按键与权限方案，不能直接解释Windows语法，真实跨应用待验 | 部分实现 | U6 MainWindow.RunDIY/DIYViewer → PetShortcuts.windowsKeys、PetKeyboardMacro、PetMacInput、KeyboardMacroEditor | 5 |
| 开发者控制台/报告 | 控制台、调试与Steam反馈窗口 | 本机诊断记录、可预览报告导出；完整动画调试未迁移 | 离线报告代替上游Steam反馈，不连接原服务 | 部分实现 | U6、U9 → A1 | 5 |
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
- A1：[AppModel](../Apps/macOS/AppModel.swift)、[PetWindow](../Apps/macOS/PetWindow.swift)、[ControlsView](../Apps/macOS/ControlsView.swift)。
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

已接入ClickText/v2/v3和LowText，625条点击、46条提醒，按原时段、模式、标签、活动/睡眠及属性范围筛选。原文件一条多行文本损坏，连同孤立尾部明确排除；160条Tags拼写按原Tag序列化默认all处理并诊断，未擅自修正原逻辑。转换目录v1独立于动画v3与存档v2。源码见[PetDialogue](../Sources/PetCore/PetDialogue.swift)、[转换工具](../scripts/convert_dialogue.py)、[气泡窗口](../Apps/macOS/PetSpeechWindow.swift)，规格见[PHASE-3D](specs/PHASE-3D.md)。

点击严格超过20秒后可结算文本属性/金币，按原即时/缓释规则；睡眠文本不唤醒。自动提醒只在空闲、可见且没有气泡时触发，不自动购买、不给休息/活动插入饥渴动作。SelectText、语音、Say动画、消息队列/流式显示尚未迁移；未做Windows同条件实机对照。

## 阶段3E随宠工具栏

原版ToolBar提供状态与工作/学习/娱乐等入口，WorkTimer显示活动时间、收益及停止反馈。iPet使用独立非激活小面板，状态/活动/商店/背包/休息/对话快捷入口和活动进度、剩余分钟、已获收益、暂停/继续/结束已接入；菜单栏或设置页启用，默认关闭。现有活动页与工具栏共用只读[ActivityFeedback](../Sources/PetCore/ActivityFeedback.swift)，操作复用原核心事务，不重复结算奖励。状态为“部分实现”：原多级菜单、鼠标自动隐藏、小标、DIY入口、完整计时/统计仍缺，详见[规格](specs/PHASE-3E.md)与[窗口实现](../Apps/macOS/PetToolbarWindow.swift)。

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

阶段5A首批本地统计：成功购买/实际花费、使用数量、有效工作/学习/娱乐时间和含完成奖金的收益，最近200条结束历史及累计次数；旧历史不补造。依据StatisticsCalHandle、TakeItem和ActivityLogs订阅 → PetProgress、PetEngine和StatisticsView。保存从v2升级v3，v1/v2原件独立保留、未来v4阻写；原消费标价/全键/调试与联网日志未完整映射，状态部分实现，真实页面未验。详细迁移/回滚见行为与交接，动画v3/文本v1保持。

阶段5B补StatisticsCalHandle的养成时间/强制睡眠/工作与非工作采样、当前金币/等级/好感及低状态经历键，触摸事件与pinch首轮计数、每物品/分类消费标价和原始药品经验/礼品好感。来源MainWindow.cs、MainWindow.xaml.cs → PetProgress.recordSample/recordUse和PetEngine/StatisticsView；原生物品ID前缀映射、结构化娱乐独立及有界字典为适配，不兼容原LPS统计导入。保存v4升级保留v1/v2/v3原件，未来v5保护；Steam上传、调试/联网全日志、原评价仍缺，部分实现，真实页面/输入待验。

阶段3X接入活动基础动画期间随机池资格及原2*rnd+20范围，工作/学习/娱乐的逻辑进度和收益不因显示动作暂停；打盹不转养成休息，动作结束恢复最新会话或默认，不复活已结束活动。依据MainLogic.IsIdel/EventTimer和MainDisplay.DisplayToNomal → PetAutonomy.canStart/poll、AppModel调度及既有PetScene.restoreBase。扩展插件池、旅行和真实活动移动/侧挂仍未完成，保存v4/素材不变，不能以组合回归替代实机体验。

阶段4A增加原生JSON导出、只读摘要预览和确认恢复，当前最新checkpoint与导入源独立保留，源文件不改，活动暂停/当前养成开关规则明确提示。依据winSaveManager本地恢复 → PetSaveStore.exportSnapshot/previewImport/restore、AppModel和ControlsView。支持原生JSON v1...v4而非Windows LPS，16MiB上限；原多档枚举、Steam/云、新建和多实例仍缺，部分实现，未来版本阻写与真实UI待验。本轮未恢复用户正式数据。

阶段3Y补活动名称搜索、类别/收藏过滤及四种升降排序，筛选不影响当前会话控制；ID收藏只在本机UserDefaults持久化，测试隔离。原work_star按Work.Name，目录身份与搜索/排序为原生适配；排程/DIY/套餐与跨机收藏未迁移。Windows存档审计详见[规格](specs/PHASE-3Y.md)：原Exp是等级内余量，普通无扩展等级转换不能外推到LevelMax；属性上限/独立好感上限/哈希仍需方案与实档样例，不能直接导入。保存v4不变，145项Swift与15项Python验证通过，真实新页面与压力待验。

阶段5C迁移原Work.Double：1倍原定义，>1需求0.5+0.4*n、等级(base+10)*n后始终FixOverLoad，收益不是等比例；原winWorkMenu等级上限4000决定最大倍率。有效定义用于推进/恢复/完成奖励，历史保存倍率，原同ID启动停止行为保留；有界1...400与请求范围校验是原生保护。JSON v5兼容v1...v4并独立留原件、未来v6拒绝，查询排序沿基础定义，选择偏好不跨页面保留。套餐/抽成/自动续费与排程仍未接入，真实倍率UI待验，压力最后。

阶段5D：SchedulePackage.lps14条经PackageFull.FixOverLoad转目录，纯核心报价/签署/活跃确认替换/原退款/严格余额续费、授权递减及关闭开关，活动页原生折叠区域；未知套餐保留不可续，未知旧定义退款0明确报告。全部Commissions引用未发现扣除实现，当前只展示工作抽成/学习1-Commissions；0授权拒绝负价续费是原生保护。到期按墙钟，不后台/加载扣款，保存失败锁后续套餐动作，重试不重放。JSON v6升级保留迁移源原件、future v7保护，真实财务UI/故障路径与DST/压力待验；日程项目/执行仍缺。


阶段5E任务1：纯Swift日程队列与编辑规则已实现，含稳定ID、工作/学习有效倍率套餐门槛、娱乐15级、尾部等待合并、指定位置插入、删除/移动前合并相邻等待及失败事务不变。未知活动ID可保留往返；最多1000项、等待1...1440分钟、倍率1...400为原生边界。新增9项核心回归，当前107核心+64渲染；应用尚无日程入口，执行/30秒衔接/循环/半程中止/持久化接入仍待任务2、3。保存v6和现有功能不变，实机与压力仍留最后。详见[阶段5E规格](specs/PHASE-5E.md)。


阶段5E任务2：日程执行核心已接入队列编辑命令、首项启动/循环、等待（不强制睡觉）、活动结束30秒衔接、整数分钟半程中止、套餐基础门槛、当前等级降倍率与调度前一次续费。停止日程保留当前活动及其暂停状态；手动活动/休息/关闭养成退出日程。未知项目保留并明确停止，续费后启动失败仍保留财务变化；运行中禁编辑。JSON v7兼容v1...v6，独立升级原件、加载/导入暂停与future v8保护，无离线补算。新增11项核心，当前118核心+64渲染；尚无日程操作界面，真实故障重试/睡眠/多屏/压力待最后。回滚v6前退出并备份整个目录，移开v7主/previous，再恢复独立pet.v6-before-upgrade原件。详见[阶段5E规格](specs/PHASE-5E.md)。


阶段5E任务3：新增原生“日程”标签与菜单入口，当前/下一项目、活动倍率添加、追加/前插等待、分钟数编辑、上下移动/删除和循环/暂停/继续/停止已接入；运行与暂停禁编辑。套餐在日程页可签署/检查，活动页保留入口与关联提示；未知活动显式报告。PetScheduleAccess由UI和命令处理共用，写失败/只读禁启动恢复和编辑，停止/暂停仍可用；保存重试不重放财务动作、不自动继续，批量物品使用期间禁操作。JSON导入预览明确日程暂停。新增5项门槛与1项等待编辑测试，当前124核心+64渲染。原版日程汇总环图、完整统计、多角色/MOD/LPS导入仍缺；新UI、真实失败恢复、睡眠/多屏及压力待验。本批保存仍v7；回滚v6使用独立升级前原件。详见[规格](specs/PHASE-5E.md)。


阶段5F：日程页增加原版工作/休息合计与配置工作比例环图，沿基础整数分钟计算，娱乐Time/2分别截断，严格>71%提示；不使用倍率后的时长，也不算执行进度。另列有效倍率时长+等待+每活动30秒衔接的自然完成一轮参考，暂停/早停/状态中止/降倍率可改变实际结果。空队列不显示NaN；未知/不可解析项保留且只汇总已识别部分，不给完整比例/估计。新增7项核心回归，当前131核心+64渲染=195 Swift、17 Python/macOS/iOS/签名通过。JSON仍v7，养成与执行规则未变；真实视觉/输入、失败恢复与压力仍待验，完整统计/DIY/MOD/多角色/旧LPS导入尚缺。详见[阶段5F规格](specs/PHASE-5F.md)。


阶段5G：本机自定义快捷名称/目标编辑、删除/置顶置底、原生页面/菜单栏/随宠Menu接入。链接与绝对本机路径显式区分，由NSWorkspace打开，不运行shell；Windows键记录保留不可执行，不支持原DIY LPS导入、多开或插件入口。独立shortcuts.json v1原子保存与previous，未来v2主或备份保护、损坏原件锁编辑、显式恢复先保留当前原件，副本保存成功才发布；与PetState/v7导入相互独立。新增9项核心，140核心+64渲染=204 Swift、17 Python/macOS/iOS/签名通过。未打开任何真实目标或写正式配置；跨应用实际打开、随宠Menu焦点/点击、恢复交互/压力仍待验。详情[规格](specs/PHASE-5G.md)。


阶段5H任务1：原生组合键/文本有序计划与配置兼容已实现；录制UI和实际发送仍待任务2，macKeys菜单禁用。宏v1校验步骤/文本/键码边界，文本按UTF16分块且不拆代理对，Tab/CRLF映射键事件；纯核心PID/权限门槛不执行平台投递。快捷配置v2读取v1不写盘，首次改写及恢复v1备份前保留独立原件；根未来v3及嵌套未来宏保护主档/备份/恢复。修复合法Unicode格式字符（如家庭emoji）被误判控制字符，真实C0/C1限制保留。宠物存档仍v7；回滚旧版先退出并备份整个目录，移开v2主档/previous后恢复独立v1原件。151核心+64渲染=215 Swift、17 Python/macOS/iOS/签名验证；未请求权限、投递真实按键或修改正式配置。独立6.1-sol审查受线程限额阻止，采用作者自查，不能替代独立审查或实机验收。详情[规格](specs/PHASE-5H.md)。


阶段5H任务2：接入原生一次组合键录制、文本步骤编辑/排序/删除及显式发送。PetMacInput为macOS适配模块，原共享核心/渲染不依赖AppKit；独立shortcut v2、宏v1、宠物v7不变。只由权限按钮申请，不全局监听、不用剪贴板；编辑窗口在前台拒绝，菜单栏与随宠Menu向明确前台PID投递down/up，目标变化/退出、权限撤销、取消、隐藏/睡眠/退出停止剩余。前台切走再返回也不续发，打开其它链接/文件先取消。状态只表示请求发送，无执行回执。151核心+64渲染+6 macOS适配=221 Swift，17 Python及macOS/iOS/严格签名验证；按键测试构造事件但使用假投递，无真实授权或跨应用输入证据。真实录制焦点、布局和目标响应仍待最终实机；独立审查受线程限额阻止，仅作者自查。第五阶段完成后按用户要求停止，不进入第六阶段；本批不代表第五阶段全部完成。详情[规格](specs/PHASE-5H.md)。


阶段5I：迁移原版本地eval_*统计，启动/重建核心登记活跃日，每15秒养成采样累计会话/日/月与含今天7/30天窗口，日键严格小于today-30删除，月键保留；注入公历/时区按日计算DST和跨年连续天数。活动接受启动登记原名称百分号键，暂停/继续/档中恢复不重复；原版Play归Study，完成率为completed/started，结束收益自然完成含奖金、其它只基础收益，未知活动不虚构分类。原生统计页展示当日/月/窗口、连续/最长、分类结束收益、逐项目及最近12个有记录月份，查询只读不回填。超400字项目键不截断而计未记录名称数量，分类汇总保留。PetProgress.counters复用，宠物JSON仍v7，不改经济、不补离线；回滚本批代码保留整个存档目录，旧版可读取现有计数键。158核心+64渲染+6 macOS适配=228 Swift、17 Python/macOS/iOS/严格签名验证，真实页面/系统改时区/睡眠及压力仍待验。详情[规格](specs/PHASE-5I.md)。


阶段5J：本机诊断页和菜单入口、当前运行200条合并日志及预览报告导出已接入。渲染缺图/回退在首次播放前装回调，保存/快捷失败、按键状态和睡眠恢复入内存日志；500字截断、连续同类同文合并，清空不碰统计/存档。默认报告只含准入环境/资源/运行值与事件次数，不含原始日志/存档/快捷目标，明确勾选才附日志；描述限10000字，改变选项须刷新预览。导出原子写恰好预览，不允许存档目录/符号链接目标覆盖，无上传/Steam身份/上游端点。宠物v7、快捷v2、宏v1不变，原控制台动画队列/任意动作/说话调试尚未迁移，不宣称完整替代。161核心+64渲染+6 macOS适配=231 Swift、17 Python/macOS/iOS/严格签名验证；日志/报告核心3项回归含上限/合并/默认排除/确定性/导出字节/写失败与符号链接保护。真实界面、选择取消、缺文件反馈、睡眠与压力仍待最后验收；独立6.1-sol审查受线程限额，作者自查。详情[规格](specs/PHASE-5J.md)。


第五阶段开发与研究交付已收尾，整体还原/实机仍未完成，按用户要求暂停。逐项证据见[交接](PHASE-5-HANDOFF.md)，平台依赖、凭据/素材和离线失败候选方案见[生态研究](ECOSYSTEM_RESEARCH.md)；不将研究状态改为生态兼容完成，阶段3/4缺口保留。


## 2026-10-03 恢复推进与提起定位

GitHub默认分支为ipet-dev，main保持上游镜像；功能对照仍固定1a06c598，以免混淆新上游与迁移基线。复核发现阶段5排程/统计/本机快捷/诊断已有实现；文档早期“尚未开始”不是当前状态。阶段3Z将raisepoint四状态坐标转为可选清单字段并接入长按及位移提起，保留原小于1逻辑单位的每轴死区。旧清单缺字段沿用点击处拖动并诊断，存档v7不变。见[规格](specs/PHASE-3Z.md)。

主要缺口仍为完整动画/特殊关联、SelectText/说话动画/语音、智能范围与跨屏、完整窗口/工具栏、多角色/数据MOD/主题、Windows旧档与多档管理、四项限时物品，以及生态接口和发行。压力/真实输入/睡眠多屏仍待验，没有同条件Windows性能结论。


阶段3AA/3AB（2026-10-03）：静态提起各阶段候选纳入，Happy放下两个原变体按随机源选择，147组合/4269帧约558.0MiB。原DisplayRaising按回调名称找阶段/类型再回退属于Graph接口机制，内置Raise树并无独立第三方特殊家族；数据MOD名字关联仍未兼容，不能制造特殊动作。说话栏保留角色名、150ms两字符、ComCheck标点停留与50ms淡出；Swift完整字素代替UTF-16分割，4000显示上限为原生边界。新句替换、隐藏/睡眠取消，不联网，不改存档。说话动画/选项/队列/语音仍独立缺口。见[3AA](specs/PHASE-3AA.md)、[3AB](specs/PHASE-3AB.md)。


阶段3AC（2026-10-03）：Self/Serious/Shining/Shy四组默认Nomal说话表情及B阶段变体已转入清单。普通待机随机选家族，A完成后显示文字并循环B；文字队列空的下一tick立即切C，气泡独立停留/淡出。忙碌/休息/按压/Ill仅文字，不影响养成会话；缺完整家族直接文字并诊断。开始回调一次性，动作替换/人工按压/隐藏/睡眠清除旧回调，渲染失败退回文字。新增4组合124帧约18.9MiB，当前151组合4393帧约576.9MiB；无性能结论。语音/选项/队列/插件Say接口仍缺，真实观感待验。见[规格](specs/PHASE-3AC.md)。


阶段3AD（2026-10-03）：原SmartMove交互超时和十档时长已接入本机设置，默认关闭、时长1200秒。到期暂停移动，真实非提起松手重新允许，提起放下/程序取消不重置；关闭自主移动优先。原Win32/Core通过MoveTimerSmartMove停窗口移动，iPet进入移动结束段并阻止新候选/兼容/自主移动结束接侧挂（手动放置侧挂保持），这是动画协调的原生适配。休息/待机/说话/养成继续。睡眠保留剩余，重启新计时、长调度间隔不补算；自定义范围/跨屏/自动回正未完成。见[规格](specs/PHASE-3AD.md)。

## 阶段3AE：移动范围原生适配（2026-10-03）

原版MWController.ScreenBorder/ResetScreenBorder使用主屏或固定矩形，SetNowScreenActivate检测当前屏幕并转换DPI；winMoveArea通过拖动缩放窗口保存外框。iPet新增主屏幕、检测当前屏幕固定范围和同样可拖动缩放的原生选择窗口，取消不修改设置；既有“角色所在屏幕”仍默认保留。原生统一左下原点points及visibleFrame，避免Dock/菜单栏；自定义跨屏矩形采用最大可容纳角色的可用屏幕交集，范围不可用时暂退角色所在屏幕并提示，保留原设置供屏幕恢复。

所有移动候选、连续移动、侧挂与位置恢复使用有效区域；说话和工具栏按物理显示器定位。原版整屏/任意矩形、默认主屏与自动换屏机制不能宣称逐像素一致：本批状态“已适配”，丰富移动整体仍“部分实现”。设置仅本机偏好，JSON v7/资源不变，真实选择窗口/多屏/睡眠与压力待验。源码依据：上述基线C#路径 → PetMovementArea、PetMovementAreaWindow、AppModel/ControlsView；详见[阶段3AE规格](specs/PHASE-3AE.md)。

## 阶段3AF：边缘检查自动换屏（2026-10-03）

原版MoveSideHideCheck先调用IfInActivateScreen，AutoChangeWindow开启且角色处于另一屏幕时SetNowScreenActivate更新固定矩形/索引；设置等窗口显示时暂缓。iPet新增默认关闭的本机开关，仅在提起释放或正常移动C结束的边缘检查执行，使用ColorSync显示器UUID与visibleFrame。跨到不同屏幕后固定当前屏幕矩形，不主动瞬移；旧edgeScreen被更新，后续侧挂/恢复用新范围。原生面板/区域选择器打开时暂缓，关闭开关保持原区域；选择范围同步激活屏幕ID，首次升级沿已有有效区域初始化。

状态“已适配”：原版屏幕索引/整屏DPI与原生稳定ID/可见points有差异；不是持续鼠标寻路。JSON v7及资源不变，尚无真实两屏拖动/缩放、显示器重排证据，原RePositionActive主动边缘放置保护另行实现。源码依据：上述1a06c598入口 → PetScreenChange、AppModel.activateScreenAtEdgeCheck和ControlsView；见[规格](specs/PHASE-3AF.md)。

## 阶段3AG：自动回正与主动边缘放置保护（2026-10-03）

原版MWController.CheckPosition/ResetPosition用严格25%越界阈值和反向距离小于主屏宽/高的守卫；垂直/水平分别只修符合条件的轴。MainDisplay.DisplayRaising在放下时设置RePositionActive=!CheckPosition，GraphHelper.StopMoving允许时先回正、再更新旗标并播放C。iPet已以PetReposition移植，并接入提起释放、正常行走/爬行停止和循环终止；正常C结束清上下文不再二次强制夹紧，主动边缘位置与未达阈值偏移得以保留。侧挂入口独立，保护不禁止原版侧挂。

状态“已适配”：左下points、visibleFrame与原WPF整屏/向下坐标有差异；安全恢复仍包括启动、用户重置/范围/尺寸改动、屏幕变化/睡眠恢复、缺资源或程序取消，以及完全不与任何物理显示器相交的放置。恢复时安全夹紧、保护旗标不持久化，与原版保存位置体验可能不同；JSON v7/资源不变。源码依据：上述基线入口→PetReposition/AppModel，见[规格](specs/PHASE-3AG.md)；真实边缘与跨屏动作仍待验，不用几何测试证明完整桌面体验。

## 阶段3AH：说话悬停与关闭/复制（2026-10-03）

原MessageBar悬停只停End/Close计时、输出继续，淡出恢复0.8；双击/菜单ForceClose终止关联Say，复制实际已输出TText.Text。iPet新增可选气泡交互，原生右键菜单在打开期间保持悬停计时；双击关闭，复制已显示文字；非激活面板不成为键盘主窗口，圆角外穿透。默认仍保持既有气泡全穿透，菜单栏/状态页关闭入口始终可用，清除待显示Say回调并进入结束阶段。

状态“已适配”：完整字素和30fps事件协调替代WPF计时；保留本机穿透默认属于平台偏好，不声称与原版默认输入完全一致。内/外置布局、选择式文本、语音和流式接口仍缺；真实悬停/菜单/焦点/圆角穿透需验收，JSON v7/资源不变。依据上述1a06c598入口→PetSpeechPlayback、PetSpeechWindow和AppModel/ControlsView；见[规格](specs/PHASE-3AH.md)。

## 阶段3AI：内/外置位置与长文本滚动（2026-10-03）

原MessageBar.SetPlaceIN下对齐500角色区域，SetPlaceOUT设置500下偏移；ScrollViewer最高400且TText变化滚动到末尾。iPet新增自动避让（保留原有默认）/角色内下对齐/角色外优先下方，空间不足改上方并夹到可见屏幕。显式内/外使用真实角色框，自动模式仍避开随宠工具栏；宽高随屏幕和内置角色区域重新计算。预先测完整文字高度保持气泡稳定，独立滚动区只渲染已输出文字，随输出滚动末尾；启用交互可手动滚动，复制仍取全部已输出文字。切换布局不重启时间轴、不重放奖励。

状态“已适配”：固定可读字号/points、稳定气泡高度、默认自动而非原内置，均为原生界面差异；位置模式保存本机，不改JSON v7/资源。4000字显示上限保留，选择式文本/语音仍缺，真实长文滚动、内置覆盖角色及鼠标/焦点留实机。依据上述基线入口→SpeechPlacement、PetSpeechWindow、AppModel/ControlsView；见[规格](specs/PHASE-3AI.md)。

阶段3AJ（2026-10-03）：选择式本地对话已接入，Tag角色筛选与Tags后续话题分离，原选择条件不额外检查mode/时间/活动。后续话题按应用后状态筛选，原池不重查，按ID选择防止索引错位；效果与统计复用v7，拒绝或验证失败不消费。原生显示效果说明/诊断，不宣称已还原原气泡描述和hostsay持久历史。见[规格](specs/PHASE-3AJ.md)，真实面板/睡眠倒计时/气泡焦点仍待验。

阶段2A（2026-10-03）纠偏：Windows实际SavesLoad使用GameSave_VPet，不是共享Core/GameSave。已实现独立桌面等级模型和原公式回归；尚未改变运行时PetState或v7。之前“保留公式”应限定共享Core子规则，不等同Windows桌面养成模型。等级/突破/剩余经验、动态上限、好感上限、CalMode源头差异以及LPS编码/库存/统计依赖见[旧档审计](LEGACY-SAVE-AUDIT.md)；先接运行时和JSON升级，再导入，禁止截断超100属性或误算剩余经验。

## 2026-10-03 / 阶段2B：桌面养成运行时与JSON v8

已接PetState、所有经验收益/投喂/定时调用、动态属性消耗与恢复、饥渴提醒、满属性统计及原生状态面板。按实际桌面GameSave_VPet实现剩余经验、独立等级/突破、负经验不降级、独立好感上限与新建金币100；旧余额保留。低心情25仍为绝对值，饥渴提醒70/60及严重度60/40/20按动态体力上限；保留CalMode源码比例>=80条件。突破降低当前上限不主动修改已有属性，合法历史超限状态可保存，下次对应属性变化按当前上限截断。

v1～v7先按旧边界验证，再迁移累计经验；高于1000级进入桌面突破序列，好感历史上限不丢失。v8要求growth及经验一致，未来v9保护，读取/预览不写盘，首次升级保留对应旧档原字节。加载活动/日程暂停，不补离线。回滚旧程序前退出并备份整个存档目录，移开v8主档/previous，再恢复对应旧版本独立原件；不可改版本号降级。正式用户数据未读写。Windows LPS导入与升级动画/通知仍缺。

完整验证记录Apple/build/verification/phase2b-final.log：201核心+95渲染+6适配=302 Swift、23 Python通过，macOS Release、iOS Simulator共享模块与严格签名通过。独立6.1-sol审查发现突破后合法属性无法保存的问题，新增日常推进及学习完成奖金两项回归，观察失败后修复并通过全套检查；极端整数解码/非法模型也有回归。真实睡眠、多屏和两小时压力仍待最后验收。规格检查点c1e4d204，详见[规格](specs/PHASE-2B.md)。

阶段4B已新增纯Swift旧LPS结构及规范固定点数值解码，原库1.11.9合成样例逐项核对；重复行/字段、ordinal首次匹配、转义和多行延续保留，输入有界，非规范数值/命名特殊哨兵显式拒绝。尚无宠物字段、库存/统计/Data/hash映射或导入界面，不能称Windows旧档已兼容；JSON v8及已有玩法不变。下一批继续字段映射和只读预览，详见[规格](specs/PHASE-4B.md)与[审计](LEGACY-SAVE-AUDIT.md)。

阶段4C新增只读LPS宠物属性候选及兼容诊断，正确区分固定点字段与普通LikabilityMax；保留负经验/钱包/缓释队列/动态属性，缺上限字段保留Exp增量，模式重算差异可见。重复/非法字段阻断候选，主人称呼只读保留。完整源字节、未知库存/统计/Data/hash均保留并报告，尚无预览窗口或确认导入，不改变JSONv8/正式数据。下一批继续库存参数/统计/扩展字段及完整性映射，见[规格](specs/PHASE-4C.md)与[审计](LEGACY-SAVE-AUDIT.md)。

阶段4D已接原hash只读校验：旧宠物MD5优先且仅覆盖宠物，根ver2 SHA512、旧根MD5/SHA512回退核对原库序列化字节。预览明确匹配/不匹配/缺失/不支持、算法和范围；重复/未知版本不猜，不匹配或不支持报告blocking。仍无整档导入界面/确认保存，库存/统计/Data映射与主人持久化继续待实现，见[规格](specs/PHASE-4D.md)及[审计](LEGACY-SAVE-AUDIT.md)。

## 阶段4E：旧库存只读完整参数预览
已新增PetLegacyInventoryPreview，保留逐条源行、Item/Food参数、数量、收藏/可用/单件/可见标记及自定义Data；普通Double/Int32/null/枚举编码按实际原库样例核对，不用同名内置目录替换。提供原按名称合并的记录索引/Int64数量与参数冲突提示，Unicode名称按ordinal区分；未知字段/类型、重复行/字段和合并Int32溢出明确报告，最多200条诊断及省略计数。PetLegacySavePreview提供inventory结果，但尚无原生自定义物品持久化、整档导入窗口或确认写入，JSON仍v8。
原库存加载继承Item.LoadSource，保留序列化Star/Data；商店LoadImageSource/LoadEatTimeSource才从设置/buytime更新商店值，不能混淆。11项库存回归覆盖原库往返、默认/大小写、数字枚举、非法值/重复/未知、null字面、同名参数及未知字段冲突、Unicode、数量溢出、诊断上限与预览接入。独立6.1-sol审查的加载路径文案问题已用RED→GREEN修复；Minor建议将夹具loads列表直接参数化遍历，留作后续夹具扩展。
后续先设计保留自定义参数/标记的原生库存持久化，再映射统计/Data并交付整档确认导入。回滚本批只读代码不改JSON或原LPS；原件无需恢复。详见[规格](specs/PHASE-4E.md)。

## 阶段4F：库存参数持久化与JSON v9
PetState.inventoryMetadata保存数量以外的物品参数/标记，库存数量仍为唯一来源。新买入时冻结当前目录参数；已有元数据不被后续购买覆盖，使用按库存效果、商店即用/售价按当前目录。最后一件消耗后移除参数，下一次购买保存新参数；lastUsedItem保留最后一件的正确动画数据。未知类型仅保留/显示，不执行原C#；CanUse=false禁使用，Food即使IsSingle=true也每件消耗，符合原Food UseAction。Visibility只过滤列表，全部价值/数量仍含隐藏项。收藏随元数据保存，与旧本机偏好取并集；未有元数据的未知旧ID仍只保留本机收藏。
JSON升级v9，读取v1…v8，首次写入前独立保留对应版本原件；v8不重复转换等级/经验。未来根v10及未来嵌套物品版本，即使载荷缺字段也禁止覆盖；旧版本头携带新参数拒绝。保存和恢复均在任何文件改变前校验完整编码的16MiB上限，避免紧凑JSON编码扩张后失败。回滚先退出、备份整个目录、移开v9主/previous，再复制独立pet.v8-before-upgrade原件为pet.json，不可改版本头降级。
原Image/Graph作为来源文字保留，图片仅通过独立安全相对resourceImagePath读取；旧来源图片不会被当作任意本机路径。原Data保留，当前倍率从本机冷却动态显示，不改写为原本地化说明。旧v8库存未存过完整参数，继续目录回退；不能声称恢复了其历史效果。原冷却按名称、本机按ID的差异保留，buytime映射另立规格。原Food Exp为Int32，无法完整保存的分数/越界目录经验入包事务拒绝，不截断。
独立6.1-sol审查两项Important（恢复输出扩张前置检查、商店/库存共享行倍率）均已RED→GREEN修复；摘要不可用项目不再称未知。25项本批针对性回归通过（5元数据/11持久化/9使用查询），完整验证见最新交接。Windows整档导入仍缺统计/Data/主人、预览窗口与确认写入，不能把v9参数模型称为旧档已兼容；最终实机压力和阶段6仍留后。详见[规格](specs/PHASE-4F.md)。

## 阶段4G：旧统计只读类型预览与暂停交接
按固定原源码用途解释Int32、Int64和普通Double；stat_money不套宠物固定点，大Int64精确保留，不先转Double。逐字段保存原info及完整源行，未知日期/布尔/固定点/文本不猜类型；重复根/键、地区格式、非法值、整数溢出及非零小数下溢明确诊断。最多200条诊断并列省略数，不丢源记录。仅唯一根的已核对、key≤400且abs≤1e12数值提供表示兼容子集；buy_{原物品名}须先映射库存ID，暂不加入子集。
PetLegacySavePreview已接statistics结果，但不应用到PetState，也未接导入窗口或确认写入。原JSON仍v9、源LPS及正式用户数据不变；回滚此批代码无需恢复档案。九项针对性回归通过，含实际NuGet样例、精确大整数、重复/未知/诊断上限、下溢拒绝及真正零/次正规数接受。独立6.1-sol审查无Important/Critical，唯一Minor因违反不静默归零合同已用一次RED→GREEN修复。详见[规格](specs/PHASE-4G.md)和[旧档审计](LEGACY-SAVE-AUDIT.md)。
按用户要求完成本批后暂停。尚缺旧Data购买冷却/套餐/排程、主人称呼持久化、完整导入预览与双原件确认流程；多角色/数据MOD/主题、部分原界面与动画、生态接入和最终实机验收仍按独立清单保留，第六阶段未开始。
