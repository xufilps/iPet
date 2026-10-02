# iPet

<img src="Apple/Design/ipet-icon-pixel-v1-master.png" alt="iPet 像素风图标" width="128">

**iPet 是基于 [VPet / VPet-Simulator](https://github.com/LorisYounger/VPet) 的 Swift 原生桌宠适配项目。** 当前版本 v0.2.0 提供 macOS 基础桌宠；共享养成核心与动画模块已支持 iOS 构建，iOS 应用界面将在后续阶段实现。

本项目复用原作萝莉斯角色与选定动画，保留部分原版养成规则，使用 AppKit、SpriteKit 和 SwiftUI 重新实现 Apple 平台的窗口、渲染及界面。它是派生项目，当前功能范围与 Windows 原版不同，也不是原作者发布的官方 Apple 平台版本。

- 项目仓库：[xufilps/iPet](https://github.com/xufilps/iPet)
- 原项目及作者：[LorisYounger/VPet](https://github.com/LorisYounger/VPet)
- 代码许可证：[Apache License 2.0](LICENSE)，保留原许可证全文。
- 素材授权：[动画与图片授权原文](Apple/ANIMATION_LICENSE.md)、[来源说明](Apple/ATTRIBUTION.md)；素材不应仅按代码许可证处理。
- 原项目简体中文 README **原文完整保留在本文后半部分**；原多语言 README 继续保留；原 C# 工程源码已从当前目录移除，可到原仓库查阅。

## 当前状态

| 项目 | 当前情况 |
| --- | --- |
| macOS | 原生基础版，最低部署目标 macOS 14 |
| iOS | 共享模块以 iOS 17 为最低目标，Simulator 交叉编译通过；尚无可安装 iOS 应用 |
| 语言与框架 | Swift 6、AppKit、SpriteKit、SwiftUI；Swift 模块无第三方包依赖 |
| 分发 | 源码可自行构建；构建脚本生成自用 ad-hoc 签名应用，尚无公证发行包 |
| 完整度 | 已实现基础陪伴与养成，尚未达到 Windows 原版功能完整度 |

## 已实现的功能

- 透明无边框桌宠窗口，不获取键盘主窗口焦点；通过菜单栏 🐾 管理应用。
- 点击头部或身体进行抚摸，拖动角色时播放提起动画；按状态快走/慢走与爬行，起步及继续移动边缘检查和位置重置。
- 待机、摸头、身体互动、提起、行走、休息、进食和饮水动画，保留逐帧时长及动作阶段。
- 体力、饱腹、饮水、心情、健康状态，以及基础经验、好感和状态判断规则。
- 13 项内置工作/学习/娱乐，金币收益与完成奖励；118 项物品、搜索分类商店、背包和药品。
- 休息/起床、中文状态/活动/商店/背包/设置五页面、大小调整与自主移动开关。
- 原版离线点击文案与饥渴提醒、原生文字气泡；菜单栏或状态页点击“聊一句”。
- 可选随宠快捷工具栏，显示活动进度与已获收益，可暂停、继续或结束活动。
- 本地 JSON 存档、自动保存、上一份有效备份、损坏文件保留及未来版本写入保护。
- 睡眠/唤醒与显示器变化的生命周期处理；隐藏时暂停渲染并释放纹理。

所选动画包含 **87 个动作/Graph/状态组合、2672 个唯一 PNG 帧，约 338.7 MiB**。它们只是原角色动画的一部分；构建工具从仓库中的原素材生成所需资源，不要求在运行时加载完整角色目录。

## 与原版的区别与未实现部分

| 内容 | Windows 原版 | iPet v0.2.0 |
| --- | --- | --- |
| 桌面技术 | C# / .NET / WPF | Swift / AppKit / SpriteKit / SwiftUI |
| 活动 | 丰富随机互动、移动、爬墙、边缘隐藏等 | 基础互动与左右移动，未实现爬墙、边缘隐藏和跨屏自主漫游 |
| 养成与经济 | 工作、学习、娱乐、购物等完整系统 | 默认/休息/活动规则、金币、购物、背包和药品；未含完整统计、排程与扩展玩法 |
| 内容扩展 | 创意工坊、数据 MOD、C# 插件 | 暂不支持第三方 MOD、原版插件或 Steam |
| 存档 | 原版 LPS 存档及保存体系 | 独立 JSON 格式，不导入或改写 Windows 存档 |
| 云端与对话 | 原项目/插件生态提供相关能力 | 本版不含云同步、AI 对话或网络服务 |
| 手机体验 | 本仓库保留的原版基于 Windows | iOS 界面尚未开发，后续按应用内养宠设计 |

保留的规则包括原版状态阈值、抚摸消耗、食物分次生效、基础日常与休息公式。v0.2.0 已用原物品目录及 PNG 图像替代用户界面的免费面包/饮料和 emoji；旧免费命令仅保留给兼容测试。活动按原默认平衡配置，保留效率、收益、食用衰减及低价赊账边界；动作变体选择和平台生命周期仍属于适配，不能视为完整玩法等价。完整能力矩阵、源码依据及迁移状态见 [原版差异说明](Apple/docs/UPSTREAM_COMPARISON.md)，公式细节见 [行为对照](Apple/docs/BEHAVIOR.md)。

## 环境要求

- macOS，安装 Xcode 16 或更高版本并启用 Swift 6 工具链。
- Python 3，用于构建前转换内置素材；Git，用于获取源码。
- 原始角色文件位于 `VPet-Simulator.Windows/mod/0000_core/pet/vup`，请保留此目录。
- 本地测试使用 arm64 Mac；最低版本 macOS 14 及 Intel Mac 尚未实机验收。

若终端尚未选择完整 Xcode，可运行 `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`。请先完成 Xcode 正常的首次启动配置。

## 获取、构建与启动

```sh
git clone https://github.com/xufilps/iPet.git
cd iPet/Apple
./scripts/build.sh
open build/Build/Products/Release/iPet.app
```

构建脚本会转换内置素材、编译 Release 应用并创建自用 ad-hoc 签名。应用位于 `Apple/build/Build/Products/Release/iPet.app`。此签名不等同 Developer ID 签名或 Apple 公证；正式发行需要另外完成这些流程。

也可使用 Xcode：

```sh
cd iPet/Apple  # 如果你还位于仓库外
python3 scripts/convert_assets.py
open iPet.xcodeproj
```

在 Xcode 中选择 **iPet** scheme 和 **My Mac**，然后运行。工程每次构建都会执行素材转换，无需 Steam、Windows `mklink.bat` 或第三方项目生成器。`scripts/create_project.py` 是确定性工程生成工具，只在维护工程结构时使用；通常直接使用已提交的 Xcode 工程。

## 使用方式

应用启动后，桌宠出现在屏幕可见区域，菜单栏显示 🐾。点击菜单可打开状态与设置、活动、商店、背包、休息/起床、显示/隐藏、重置位置及退出。

点击角色头部或身体进行抚摸；移动超过拖动阈值后进入提起动作，拖动期间暂停自主移动。右键角色打开设置。桌宠大小支持 150–500 点，默认 280 点；设置窗口支持 ⌘,，退出支持 ⌘Q。

透明区域按当前帧 alpha 采样处理鼠标穿透，轮询频率为 30 Hz；快速移入后立即点击仍需进一步实机验证。桌宠本身不获取键盘焦点，主动打开设置时应用正常激活。

活动页可开始、暂停、继续或提前结束活动，工作赚金币，学习/娱乐获得经验；提前结束不发完成奖金。商店可购买即用或放入背包，背包使用一件才改变状态。重复食用同一物品会衰减全部属性增量，原负面效果也会保留。低价低经验增量物品可赊账；价格或物品经验增量≥1000 时，余额必须高于售价。

休息、食物与药品可以恢复状态；免费的应急药也有经验、体力、好感代价，先看商品效果。退出应用和系统睡眠期间不补算状态消耗；隐藏桌宠会暂停动画，但应用运行期间养成继续。隐藏后可从菜单栏重新显示；位置异常时使用“重置位置”。

## 存档、偏好与恢复

为兼容更名前的原生测试版，正式存档目录继续使用历史路径：

```text
~/Library/Application Support/VPetApple/
├── pet.json                  # 主存档
├── pet.previous.json         # 上一份有效存档
├── pet.v1-before-upgrade-UUID.json # v1 升级前独立原件
└── pet.corrupt-UUID.json      # 检测到损坏时保留的原文件
```

每 60 秒、关键互动、系统睡眠及正常退出时保存。存档采用带版本号的 Codable JSON 和原子写入；损坏主文件被保留后尝试恢复备份。遇到不支持的未来版本主文件或备份，程序拒绝覆盖；加载失败的会话会明确提示并停止写入。

恢复前先退出应用，复制整个存档目录，再用确认有效的备份替换主文件。保留未来版本或损坏证据，不要直接删除所有文件来尝试修复。设置面板提供“打开存档目录”入口。该目录与 Windows 原版存档相互独立。

大小、位置和自主移动开关存于 UserDefaults。iPet bundle ID 为 `org.xufilps.iPet`；更名前 `org.xufilps.VPetApple` 中已有的偏好，只在新标识缺少对应值时导入，原偏好不删除。

## 源码结构

```text
Apple/
├── Package.swift                  # PetCore / PetRendering 共享库
├── iPet.xcodeproj/                 # macOS 应用工程与 iPet scheme
├── Sources/
│   ├── PetCore/                    # 平台无关养成、命令、时钟、随机源、存档
│   ├── PetRendering/               # 资源清单、SpriteKit、动作阶段、alpha 命中
│   └── iPetMac/                    # AppKit 窗口、SwiftUI 面板、菜单、生命周期
├── Tests/                         # 核心规则、保存保护与渲染测试
├── scripts/                       # 转换、构建、验证与真实运行观察工具
├── Resources/PetAssets/            # 构建生成，Git 忽略
└── docs/                          # 计划、行为对照、验证证据与交接
```

原 C# 工程与 `VPet.sln` 已从当前源码树移除，源码和完整 Windows 项目见 [原仓库](https://github.com/LorisYounger/VPet)，行为对照固定在上游基线 `1a06c598`。`VPet-Simulator.Windows/` 目前仅保留 `mod/0000_core` 原素材与配置，供构建前转换使用；它不再包含 Windows 应用源码。Git 历史仍可恢复原文件，未重写历史，因此此次清理不会消除历史对象或让整个克隆体积等比例缩小。共享核心不依赖 AppKit/UIKit/SpriteKit，动画层不直接修改养成数据；平台窗口和应用生命周期由 macOS 应用处理。后续 iOS 将复用共享模块，单独实现触摸界面和前后台策略。

## 测试与验证边界

```sh
cd Apple
./scripts/verify.sh
```

脚本运行素材转换、核心/渲染测试、macOS Release 构建、签名校验，以及共享模块的 iOS Simulator 交叉编译。完整日志保存在 `Apple/build/verification/`，生成内容不提交到 Git。

资源转换共有 10 项 Python 回归检查，覆盖未变化输出不重写、源图/配置更新、缺失/损坏输出恢复，以及无效源和配置仍被拒绝；每次仍校验源内容，不依赖修改时间跳过检查。该优化减少构建时重复写入，不改变养成或存档。

当前 Swift 自动测试包含 32 项核心测试和 8 项渲染测试，覆盖原版公式边界、确定性模拟、分次投喂、损坏恢复、未来版本保护、经验下降后的历史好感、帧顺序与时长、动作阶段、缺文件、逻辑坐标、alpha 命中和缓存释放。

真实两小时观察可运行：

```sh
python3 Apple/scripts/soak.py --seconds 7200 --output Apple/build/soak-2h.json
```

该工具使用隔离临时存档，按墙钟时间切换动作与状态、隐藏恢复，并采样 CPU 与 RSS；结束后关闭测试实例。应用内模拟暂停/恢复不等同让整台 Mac 真正睡眠。v0.1曾有两分钟真实动作压力测试通过，v0.2尚无新增长期实机证据；测试中的“两小时养成模拟”使用注入时钟，**不能代替真实两小时运行观察**。

按当前用户决定，实机验收暂缓：真实两小时长期稳定性、实际拖动焦点、快速点击穿透、多屏热插拔、不同屏幕倍率和系统睡眠唤醒仍未完成；这不等于已经通过，也不阻止继续推进可自动验证的改进。没有与 Windows 原版做同条件性能比较，因此不声称 iPet 更省资源或更稳定。完整证据见 [交接文档](Apple/docs/HANDOFF.md)。

## 许可证、素材与派生说明

**代码**继续遵守 [Apache License 2.0](LICENSE)，原 `LICENSE` 全文保持不变；原作者署名、版权说明和历史保留。新增 Swift 实现与更名修改在 [NOTICE](NOTICE)、源码注释和 Git 历史中标识。发布代码时应保留许可证和适用的署名/告知文件。

**原作内置动画与图片**具有单独授权，版权归虚拟主播模拟器制作组。非商用使用需向用户告知来源并提供原项目链接；分发动画时必须告知授权信息、提供原项目链接，且禁止收费分发动画。商业使用须遵循原声明的醒目来源告知、页面链接、联系作者及其他要求，不能仅凭 Apache 2.0 推定素材可任意商用。Zip 照片图库禁止商用，iPet 本版不包含该图库。

[原动画与图片授权全文](Apple/ANIMATION_LICENSE.md)按当前仓库原 README 的声明保留，来源链接为 [LorisYounger/VPet](https://github.com/LorisYounger/VPet)。构建出的应用附带 `LICENSE`、`NOTICE`、`ATTRIBUTION.md` 和 `ANIMATION_LICENSE.md`，设置面板也提供原项目与授权链接。原版 `CONTRIBUTING.md` 与 README 的部分商用授权措辞存在差异；需要商用时应联系原权利方确认，不将旧措辞视为扩大授权。

感谢 LorisYounger、VPet 原项目贡献者，以及虚拟主播模拟器制作组提供的原始代码、角色和动画。本仓库使用原 Git 历史保留来源，iPet 改动集中在 Apple 原生实现、构建工具及文档。

## 后续方向与贡献

按 [分阶段还原路线](Apple/docs/ROADMAP.md) 先验证 macOS 稳定性，再依次推进养成经济、动作与原生界面、数据兼容、扩展集成，最后扩展 iOS 与发行。每阶段动工前形成具体规格，以可观察行为和验证记录验收，不设无依据日期。C# 插件、Steam/工坊和受授权限制素材独立研究，不预先承诺完全兼容。

当前采用参考原版形象生成的像素风图标，母图、小尺寸导出、来源和重建方法见 [图标记录](Apple/Design/README.md)。保留原项目图标；新图标不改变原角色及动画授权。

问题反馈和贡献请使用 [iPet Issues](https://github.com/xufilps/iPet/issues) 与 Pull Requests。涉及 Swift 版的改动应执行 `Apple/scripts/verify.sh`，说明行为变化和验证边界；新增或替换素材需明确来源与授权。对原项目贡献，请遵循下方原 README 和原 `CONTRIBUTING.md` 的流程。

---

## 原项目 README.md（原文保留）

以下完整保留原 VPet 简体中文 README 原文，对照上游基线 `1a06c5981330564bab05a098d2d7969a4b119dd3`。后续内容描述原 Windows 项目、原发布渠道和原授权；iPet 的当前状态以上文为准。原文中的源码相对链接、Windows 工程和构建说明属于历史内容，现应到 [原仓库](https://github.com/LorisYounger/VPet) 阅读使用；下面的原文仍保持逐字节不变。


## v0.2.0 养成升级与验证边界

旧原生 JSON v1 加载保留原属性，首次升级补入 1000 金币、空背包与食用历史；写 v2 前保留独立 v1 原件，不随日常备份轮换覆盖。未知物品和活动 ID 保留，无法使用的条目明确显示；加载中的活动暂停，用户决定继续或结束，退出/睡眠不追补活动时长和收益。食用衰减按墙钟到期，这与离线养成扣减不同。

回滚到 v0.1 时先退出并复制整个存档目录，移开 v2 主档和 previous 备份，再复制独立 v1 原件为 pet.json；不要让旧程序覆盖新档或删除未来版本证据。Windows LPS 导入仍未实现。

本阶段自动验证涵盖 32 项核心测试、8 项渲染测试、10 项 Python 检查、macOS Release 构建及 ad-hoc 签名检查、iOS Simulator 共享模块编译。预期值由原 C# 源码独立推导，尚未运行 Windows 程序作同条件对比。原生界面、两小时资源观察、输入、睡眠、多屏和 Intel/最低系统实机验收按用户决定暂缓。详见 [阶段2规格](Apple/docs/specs/PHASE-2.md)、[实施记录](Apple/docs/PHASE-2-EXECUTION.md) 和 [交接](Apple/docs/HANDOFF.md)。

# VPet-Simulator

简体中文 | [繁體中文](./README_zht.md) | [English](./README_en.md) | [日本語](./README_ja.md)

虚拟桌宠模拟器 一个开源的桌宠软件, 可以内置到任何WPF应用程序

![主图](README.assets/%E4%B8%BB%E5%9B%BE.png)

获取虚拟桌宠模拟器 [OnSteam(免费)](https://store.steampowered.com/app/1920960/VPet) 或 通过[Nuget](https://www.nuget.org/packages/VPet-Simulator.Core)内置到你的WPF应用程序

## 虚拟桌宠模拟器 详细介绍

虚拟桌宠模拟器是一款桌宠软件,支持各种互动投喂等. 开源免费并且支持创意工坊.

反正免费为啥不试试呢(

该游戏为 [虚拟主播模拟器](https://store.steampowered.com/app/1352140/_/) 内置桌宠(教程)程序独立而来, 如果喜欢的话欢迎添加 [虚拟主播模拟器](https://store.steampowered.com/app/1352140/_/) 至愿望单

### 超多的互动和动画

多达 32(种) * 4(状态) * 3(类型) 种动画, *注:部分种类没有生病状态或循环等内容,实际动画数量会偏少*

#### 一些动画例子:

##### 摸头

![ss0](README.assets/ss0.gif)

##### 提起

![ss4](README.assets/ss4.gif)![ss4](README.assets/ss8.gif)

##### 爬墙

![ss7](README.assets/ss7.gif)

### 免费

该游戏完全免费! 反正不要钱,试试不要紧(<br/>
该游戏主要目的是宣传下 [虚拟主播模拟器](https://store.steampowered.com/app/1352140/_/), 这是虚拟主播模拟器里面的桌宠.

### 开源

该游戏在github上开源, 欢迎提出自己的想法,创意或者参与开发!<br/>
您还可以修改代码来制作自己专属的桌宠!(虽然说大部分内容都支持创意工坊,不需要修改代码)<br/>
项目地址: https://github.com/LorisYounger/VPet

### 支持创意工坊

该游戏支持创意工坊,您可以制作别的人物桌宠动画或者互动,并上传至创意工坊分享给更多人使用.

MOD制作器:  https://github.com/LorisYounger/VPet.ModMaker

创意工坊支持添加/修改以下内容

* 桌宠动画
* 物品/食物/饮料等
* 自定义桌宠工作
* 说话文本
* 主题
* 代码插件 - 通过编写代码给桌宠添加内容
  * 添加新的动画逻辑/显示方案 (eg: l2d/spine 等)
  * 添加新功能 (闹钟/记事板等等)
  * 几乎无所不能, 示例例子参见 [VPet.Plugin.Demo](https://github.com/LorisYounger/VPet.Plugin.Demo)


### 反馈&建议&联系我们

如果有建议或者意见,可以在Steam商店评论/社区,Github Issue,虚拟主播模拟器贴吧,虚拟桌宠模拟器MODDer群(907101442)或者邮件联系我 [mailto:service@exlb.net](mailto:service@exlb.net)

## 软件结构

* **VPet-Simulator.Windows: 适用于桌面端的虚拟桌宠模拟器**
  * *Function 功能性代码存放位置*
    * CoreMOD Mod管理类
    * MWController 窗体控制器
  
  * *WinDesign 窗口和UI设计
    * winBetterBuy 更好买窗口
    * winCGPTSetting ChatGPT 设置
    * winSetting 软件设置/MOD 窗口
    * winConsole 开发控制台
    * winGameSetting 游戏设置
    * winReport 反馈中心
  
  * MainWindows 主窗体,存放和展示Core
  * PetHelper 快速切换小标
* **VPet-Simulator.Tool: 方便制作MOD的工具(eg:图片帧生成)**
* **VPet-Simulator.Core: 软件核心 方便内置到任何WPF应用程序(例如:VUP-Simulator)**
  * Handle 接口与控件
    * IController 窗体控制器 (调用相关功能和设置,例如移动到侧边等)
    * Function 通用功能
    * GameCore 游戏核心,包含各种数据等内容
    * GameSave 游戏存档
    * IFood 食物/物品接口
    * PetLoader 宠物图形加载器
  * Graph 图形渲染
    * IGraph 动画基本接口
    * GraphCore 动画显示核心
    * GraphHelper 动画帮助类
    * GraphInfo 动画信息
    * FoodAnimation 食物动画 支持显示前中后3层夹心动画 不一定只用于食物,只是叫这个名字
    * PNGAnimation 桌宠动态动画组件
    * Picture 桌宠静态动画组件
  * Display 显示
    * basestyle/Theme 基本风格主题
    * Main.xaml 核心显示部件
      * MainDisplay 核心显示方法
      * MainLogic 核心显示逻辑
    * ToolBar 点击人物时候的工具栏
    * MessageBar 人物说话时候的说话栏
    * WorkTimer 工作时钟

## 参与开发

欢迎参与虚拟桌宠模拟器的开发! 为保证代码可维护度和游戏性,如果想要开发新的功能,请先[邮件联系](mailto:zoujin.dev@exlb.org)或发[Issues](https://github.com/LorisYounger/VPet/issues)我想要添加的功能/玩法, 以确保该功能/玩法适用于虚拟桌宠模拟器. 以免未来提交时因不合适被拒(而造成代码浪费)<br/>
如果是修复错误或者BUG,无需联系我,修好后直接PR即可

当想法通过后,您可以通过 [fork](https://github.com/LorisYounger/VPet/fork) 功能拷贝代码至自己的github以方便编写自己的代码, 编写完毕后通过[pull requests](https://github.com/LorisYounger/VPet/compare) 提交<br/>
如果您想法没有被通过,也可以另起炉灶,写个不同版本功能的桌宠软件. 但需遵守 [Apache License 2.0](https://github.com/LorisYounger/VPet/blob/main/LICENSE) 与 [动画版权声明与授权](https://github.com/LorisYounger/VPet#%E5%8A%A8%E7%94%BB%E7%89%88%E6%9D%83%E5%A3%B0%E6%98%8E%E4%B8%8E%E6%8E%88%E6%9D%83)
注: 一般来讲, 添加新功能都可以通过编写代码插件MOD实现, 详情请参见 [VPet.Plugin.Demo](https://github.com/LorisYounger/VPet.Plugin.Demo)

我可能会对您的提交的代码进行修改,删减等以确保该功能/玩法适用于虚拟桌宠模拟器.


感谢以下参与的开发和翻译人员

<a href="https://github.com/LorisYounger/VPet/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=LorisYounger/VPet" />
</a>

和提供社区翻译和更多内容的创意工坊人员

## 动画版权声明与授权

在github中 [桌宠动画文件](https://github.com/LorisYounger/VPet/tree/main/VPet-Simulator.Windows/mod/0000_core/pet/vup) 动画版权归 [虚拟主播模拟器制作组](https://www.exlb.net/VUP-Simulator)所有, 当使用本类库时,您可能需要自行准备动画文件,或遵循以下协议

> **注 **
> 本动画声明仅限于桌宠自带的动画, 若有画师/开发者画自己的动画适配给桌宠,并不遵循用本声明

### 非商用用途授权

* 需要向用户告知动画文件来源并提供访问 [该页面](https://github.com/LorisYounger/VPet) 的链接
* 当您完成以上要求后,您可以免费使用动画文件

### 商用用途授权

* 第一次使用时需弹窗并醒目的向用户告知动画文件来源并提供访问 [该页面](https://github.com/LorisYounger/VPet) 的链接
* 在相应页面(用户可以快捷访问)向用户告知动画文件来源并提供访问 [该页面](https://github.com/LorisYounger/VPet) 的链接

* 禁止通过出售动画文件进行盈利
* 请[邮件联系](mailto:zoujin.dev@exlb.org)我
* 当您完成以上要求后,您可以免费使用动画文件

### 分发动画文件

* 需要告知以上所有授权信息
* 需要提供访问 [该页面](https://github.com/LorisYounger/VPet) 的链接
* 分发动画文件时禁止任何付费/收费行为

### 图片版权声明与授权

* 程序内置图片 版权授权同上
* Zip 照片图库禁止商用

## 桌面端部署方法

1. 下载本项目, 通过VisualStudio打开 `VPet.sln` 文件
2. 在生成栏中, 选择 位数为 `x64` 和生成项目为 `Vpet-Simulator.Windows`
   ![image-20230208004330895](README.assets/image-20230208004330895.png)
3. 点击启动, 如果一切正常则会报错 `缺少模组Core,无法启动桌宠`
4. 以管理员身份运行 `mklink.bat`, 这会让mod文件链接到生成位置
5. 再次点击启动即可正常运行
