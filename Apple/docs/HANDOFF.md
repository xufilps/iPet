# iPet 交接 — 2026-10-01 / v0.1.0

## 交付与版本

分支 `codex/swift-macos`，原版基线 `1a06c598`。计划/骨架提交 `97bb11ac`，核心与存档提交 `b6252df4`，原生应用与渲染提交 `ece45708`；后续修订包含按显示尺寸解码纹理与交付文档。原生版验证时为本地提交；更名后将源码发布到 https://github.com/xufilps/iPet，未创建正式发行包。

可运行产物：`Apple/build/Build/Products/Release/iPet.app`（约66 MiB，自用 ad-hoc 签名）。使用 `Apple/scripts/build.sh` 重建，或按 Apple/README.md 打开 Xcode 工程。产物与转换资源为可再生文件，未重复提交到 Git。应用、构建工具、资源授权及恢复说明均已交付；iOS 本阶段仅共享模块，无可安装 iOS 应用。

## 验证证据与边界

测试环境：arm64 macOS 27.0 (26A428)，Xcode 27.0 (27A266a)，Swift 6.4。最低部署目标为 macOS 14 / iOS 17，未在最低版本实机运行。

| 检查 | 结果 |
| --- | --- |
| 核心测试11项 | 通过：默认tick、CalMode、投喂/分次释放、setter副作用、抚摸/休息、暂停/时钟反转、固定种子两小时模拟、备份恢复、未来主/备份版本保护、等级下降历史好感、写入失败/非法值 |
| 渲染测试5项 | 通过：完整清单/回退、帧排序/时长/分层、阶段循环/结束/10000次打断、缺文件拒绝、500逻辑画布命中/真实alpha/纹理缓存限制与释放 |
| macOS Release构建与签名 | 通过 xcodebuild、ad-hoc签名、codesign --verify --strict |
| iOS Simulator共享模块 | PetRendering及PetCore交叉编译通过，arm64-apple-ios17.0-simulator；不是iOS界面或真机验收 |
| GUI核对 | 已显示完整角色与中文设置；实际点击设置中的休息/起床、隐藏/显示正常。修复初次实机发现的1000像素帧裁切与长文案截断 |
| 短时真实渲染压力 | 按墙钟120秒切换动作/状态、隐藏恢复与模拟暂停恢复，记录CPU和RSS；数值见下方性能记录 |
| 独立代码审查 | 发现的状态图层覆盖、初始休息动画、未来备份写入和经验下降存档边界均已修复并复核 |
| 真实两小时持续运行 | **待验**；自动测试中的两小时是加速逻辑模拟，短时压力测试不能证明无长期内存增长 |
| 实际输入与系统环境 | 快速移入即点击的穿透时序、实际拖动焦点、多屏热插拔、不同倍率与系统睡眠唤醒仍待实机完整验收 |

生成资源：27个动作/状态组合、559个唯一PNG帧，约63.1 MiB，来源SHA-256记录在生成目录的 sources.sha256.json。按动作/帧使用，不载入全部834 MB角色资源。解码分辨率随窗口大小和屏幕倍率调整到256–1024像素档位；纹理缓存估算上限48 MiB，GPU、当前节点与系统库内存不包含在该数字中。

最终120秒压力测试（进程含约8秒启动/测试准备，采样总历时130.28秒）：30秒后的RSS范围 135.4–196.8 MiB，最后采样 185.8 MiB；CPU采样中位数 12.4%，最高 25.2%。动作频繁切换会增加解码成本；这些短时数据不构成长时间泄漏或能耗结论。

完整自动验证命令：`Apple/scripts/verify.sh`。本地完整日志：`Apple/build/verification/`；短时压力原始记录：`Apple/build/soak-final-120s.json` 与同名 `.log`。真实两小时观察命令：`python3 Apple/scripts/soak.py --seconds 7200 --output Apple/build/soak-2h.json`，默认在结束后关闭测试实例。观察期间避免手动改变桌宠状态；测试存档位于系统临时目录，正式存档不受影响。脚本调用应用内暂停/恢复，不会让整台Mac进入睡眠。

## 恢复与后续

正式存档位于 Application Support/VPetApple；恢复前退出应用并复制整个目录，保留未来版本和损坏文件。构建失败可回退 Apple 相关提交，原C#与素材文件未修改。工作区出现的其他未跟踪 `.DS_Store` 未纳入交付提交，也未清理。

下一步先完成真实两小时和输入/多屏/睡眠验收，再按 ROADMAP.md 推进养成经济、动作界面、数据兼容、扩展集成，最后实现 iOS 与发行；每阶段先形成具体规格。

## iPet 更名与源码发布

应用、Swift Package、Xcode工程/scheme、菜单与脚本统一更名为iPet，bundle ID为org.xufilps.iPet。历史存档目录VPetApple保留，新bundle缺少的偏好从旧bundle导入（smoke模式不迁移正式偏好）。README新增完整原生版说明，并在末尾完整保留原README的7775字节；LICENSE与上游字节一致，NOTICE、原作者署名与动画图片授权随源码及应用保留。

目标GitHub仓库：https://github.com/xufilps/iPet，默认分支main。仅以正常快进推送发布源码，不创建Release或公证安装包；本次更名不改变已有两小时/多屏/睡眠等待验边界。构建验证日志位于build/verification；更名启动测试使用隔离存档并自动退出。

## 像素风图标与原版还原路线修订

当前分支 `codex/ipet`，应用版本仍为v0.1.0。新增参考原图生成的pixel-v1图标、1024母图、16–1024导出、AppIcon配置及生成说明；此前白色小宠物候选保留，但不进入应用。Finder的iPet简介已实际显示新图标（小图与预览均核对）；Release产物包含AppIcon.icns/Assets.car，Info.plist的CFBundleIconName为AppIcon。图标来源见Design/README.md，原角色授权与原素材保持不变。

本轮重新通过11项核心和5项渲染测试、macOS Release/ad-hoc签名验证、iOS Simulator共享模块编译、图标尺寸/资源槽检查、工程重复生成一致性、本地文档链接检查，以及原README后缀7775字节与LICENSE完整性。独立审查复核资源哈希、工程配置、源码依据和未完成状态，无重要待修复问题。设备环境沿用上述arm64 Mac；未新增最低系统、Intel或iOS真机验收证据。验证日志仍在build/verification。

新增UPSTREAM_COMPARISON.md作为能力清单及持续差异矩阵，ROADMAP.md明确0–6阶段门槛；本轮只完成图标配置和文档，不改变养成/存档。两小时真实运行、快速点击/拖动焦点、多屏和系统睡眠仍待验收；不宣称性能优于原版。回滚本轮图标/文档提交即可恢复此前工程，保留正式存档和原资源；图标哈希位于Design/SHA256SUMS，当前产物哈希位于BUILD_MANIFEST.sha256。

## 当前树精简与实机验收暂缓 — 2026-10-01

删除原C#工程及Windows目录非mod文件共278个已跟踪文件；保留构建所需mod/0000_core的PNG/LPS、原图标、原README后缀、LICENSE、署名及独立素材授权。差异矩阵改为原仓库固定基线链接；较早交接中的“原工程保留”描述历史版本，现在以本节及根README为准。Git历史未重写，已有本地未跟踪.DS_Store保持不动。

实机两小时、输入、多屏及系统睡眠验收按用户决定暂缓，仍未通过，不以构建或测试替代；后续自动验证优化可以独立推进。此轮不改Swift养成、存档接口/格式及素材转换路径。回滚使用Git revert恢复清理提交，正式存档不修改；当前树不含原工程，完整项目可在https://github.com/LorisYounger/VPet查阅。

精简后重新通过16项Swift测试、macOS Release/签名和iOS共享模块编译；工程生成、当前文档本地链接、原README/许可证完整性检查通过。跟踪树中无C#/WPF工程代码，资源转换仍为27个组合、559帧、63.1MiB。

## 资源输出写入优化 — 2026-10-01

每次重新解析源配置、校验PNG签名/尺寸头并比较输出字节；仅跳过内容相同的PNG/JSON写入，不依赖mtime或缓存标记跳过源读取。缺失或内容损坏输出重建，无效PNG先检查再写该帧。6项Python回归检查通过：重复转换不改mtime/内容、源图变更、配置变更、输出恢复、无效PNG拒绝且不覆盖该帧、非法配置仍拒绝。测试先复现重复写入及无效帧覆盖失败，再修复通过；16项Swift测试、macOS Release/签名及iOS共享模块编译重新通过。原README/许可及Swift养成/存档保持不变。

完整素材重复转换核对559帧及2份JSON，共561份输出的SHA256和mtime保持不变，记录在build/verification/conversion-repeat.json。Python检查日志为conversion-tests.log；不声称整体构建提速、运行时性能变化或完整PNG解码校验。独立审查确认素材依赖/许可未删，源码固定基线链接存在；文档残留和源校验覆盖建议已修正。回滚资源脚本提交后重新转换可恢复旧构建流程，无需操作用户存档。

## v0.2.0 阶段2交接 — 2026-10-02

交付13项内置活动、118项物品与原图、金币/经验收益、完成奖金、购物/背包/药品、食用衰减、五个原生页面以及JSON v1→v2升级。详见[实施记录](PHASE-2-EXECUTION.md)、[规格](specs/PHASE-2.md)及[行为对照](BEHAVIOR.md)。4条限时商品排除；原随机变体池、统计/排程、第三方MOD、LPS导入、C#插件、Steam/云同步和iOS应用仍不支持。

自动验证环境为arm64 Mac、macOS27.0 (26A428)、Xcode27.0 (27A266a)、Swift6.4，源码语言模式Swift6，部署目标macOS14/iOS17。30项核心、7项渲染、10项Python检查通过；macOS Release构建/ad-hoc签名检查与iOS Simulator共享模块编译通过，工程生成两次字节一致，原README 7775字节后缀及LICENSE保持。原始日志在Apple/build/verification/，不纳入Git。未运行应用进行本轮实机体验/长期资源测试；v0.1的历史120秒观察不代表v0.2证据，最低系统与Intel也待验。

所选清单为67个动作/Graph/状态组合、2158个唯一PNG帧（约271.8MiB），物品图片另计；缓存估算上限仍48MiB，节点持有纹理和SpriteKit/GPU开销另计，不能作为进程RSS保证。新活动增加包体，不声称比原版更省资源。缺状态回退同Graph正常/其他状态；studytwo/Happy缺结束阶段，跳绳按B目录首个变体，Gift非法源透明度截断并记录诊断。PNG完整解码在渲染时进行，转换只校验头与尺寸。

存档目录仍为Application Support/VPetApple。升级前独立保留pet.v1-before-upgrade-UUID.json；正常previous轮换不覆盖此原件。活动加载后暂停，用户继续；睡眠/退出不补算。未知商品/活动ID保留并在面板提示，未来格式或目录版本暂停写入。保存失败只提示，不重放购买/使用；再保存只是写当前快照。

回滚先退出并复制整个存档目录。v0.1不能读取v2；移开v2 pet.json与pet.previous.json，再复制独立v1备份为pet.json，保留新档与所有故障证据。回退代码需将核心、资源清单、目录、生成工程及UI相关提交一起回退。v1升级初始1000金币仅补一次；不要反复用旧档测试正式进度。后续先由用户体验当前养成闭环，再形成阶段3具体规格；实机门槛继续单列待验。
