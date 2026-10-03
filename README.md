# iPet

<img src="Apple/Resources/Assets.xcassets/AppIcon.appiconset/icon-128.png" width="96" alt="iPet 像素风图标">

iPet 是基于 [VPet / LorisYounger](https://github.com/LorisYounger/VPet) 的 Swift 原生桌宠，优先还原 macOS 日常养宠体验，再扩展 iOS 应用内养宠。当前版本为 **v0.2.0 开发版**，提供源码与自用构建，尚无正式公证安装包或完整 iOS 应用。

- macOS 14+，Swift 6，AppKit 桌面窗口、SpriteKit 动画、SwiftUI 功能面板。
- 原生共享核心支持 iOS 17+编译；这不等于已交付 iOS 应用。
- 开发及贡献分支为 **`ipet-dev`**，也是 GitHub 首页默认分支；`main` 仅同步原 Windows 项目。
- 当前已恢复功能推进，阶段2D新增升级动画与通知、阶段3AK补随宠活动分组菜单、3AL加入可选自动隐藏、3AM补四种计时显示、2E补商品低价修正，最近完成本机基本验收。实际完成与待验证项见 [交接](Apple/docs/HANDOFF.md)。

## 快速构建

需要 macOS、Xcode 16+（Swift 6）及 Python 3，没有第三方 Swift 依赖。不需要 Steam、Windows 或 .NET；开发用原库证据生成器另行使用 .NET，不参与应用构建。

只需当前版本可单分支浅克隆：
```sh
git clone --depth 1 --single-branch --branch ipet-dev https://github.com/xufilps/iPet.git
cd iPet
bash Apple/scripts/build.sh
open Apple/build/Build/Products/Release/iPet.app
```

也可打开 `Apple/iPet.xcodeproj`，选择共享 `iPet` scheme。首次构建自动把内置 LPS/PNG 转成运行时资源；无需在线下载素材或解析 LinePutScript。命令行构建为自用 ad-hoc 签名，不是 Developer ID 签名或公证发行。

**GitHub 不包含 `Apple/build/`。** 这是本机生成的应用、编译结果和日志目录，已被忽略；运行构建脚本后会出现。`Apple/.build/` 和 `Apple/Resources/PetAssets/` 同样是可再生成输出，不应提交。原始构建输入已在仓库的 `Assets/Upstream/VPet/Core/` 中。

## 当前功能

| 范围 | 已实现内容 |
| --- | --- |
| 桌面互动 | 透明桌宠、按帧alpha穿透、抚摸、长按捏脸、提起/拖动、隐藏/显示与位置恢复；可选随宠工具栏 |
| 动作与反馈 | 154个动作/Graph/状态组合、4475张选用PNG帧；待机/特殊待机、状态过渡、说话、进食、休息、移动与边缘动作 |
| 养成 | 体力、饱腹、口渴、心情、健康、好感；桌面剩余经验/等级突破与动态上限，抚摸、分次投喂、休息和疾病状态判断 |
| 活动与经济 | 13项工作/学习/娱乐，收益与完成奖励、倍率、暂停/继续/停止；118项物品与原图片，购买即用/入包、库存检索/收藏/批量使用、药品与重复食用衰减 |
| 日程与本地记录 | 14项活动套餐、日程队列及循环控制；购买/使用/活动统计、结束历史、陪伴时间及活跃日评价 |
| 原生界面 | 中文状态、对话、活动、日程、商店、背包、统计、快捷、诊断与设置页面；本地气泡、671条基础文案及189条选择式对话 |
| 数据与工具 | 版本化JSON、自动备份、显式导出/确认恢复、未知/未来版本保护；本机快捷/按键适配及可预览诊断报告 |

组合数不是原版完整动画或功能数量。现有能力也不等于所有交互场景已通过实机验收；平台适配与原版差异逐项记录在 [对照矩阵](Apple/docs/UPSTREAM_COMPARISON.md)。

菜单栏提供显示/隐藏、重置位置、休息与功能面板。随宠工具栏默认常驻，可在设置开启“离开后自动隐藏”：离开4秒隐藏、悬停桌宠恢复、菜单操作保持。桌宠本身不成为键盘主窗口；打开功能面板会正常激活应用。拖动暂停自主移动，隐藏暂停渲染；应用仍运行时养成继续。退出和系统睡眠不补算养成或活动收益，恢复后重建计时基准。

## 存档与恢复

正式数据仍位于 `~/Library/Application Support/VPetApple/`，保留历史目录名以避免丢档；这与已删除的旧 `VPetApple.app` 无关。

当前宠物存档为 **JSON v9**，主档 `pet.json`，上一份有效备份 `pet.previous.json`。每60秒、关键互动、睡眠和正常退出保存。损坏原件会保留，再尝试有效备份；未来版本或加载失败停止覆盖写入。支持读取旧iPet v1～v8，首次升级写入前保留独立旧版本原件。

恢复或回滚前先退出应用，复制整个数据目录。旧程序应使用对应版本的 `pet.vN-before-upgrade-*.json` 副本；不要修改版本号冒充降级，不要删除未来版本或损坏证据。界面的导出/预览恢复仅支持iPet JSON。

**Windows LPS整档导入尚未开放。** 当前已有结构、宠物、库存、统计与hash的只读解析/预览；扩展Data、主人称呼持久化和完整预览/确认写入仍缺。详见 [旧档审计](Apple/docs/LEGACY-SAVE-AUDIT.md)。

## 工程结构

```text
.github/                   问题/PR模板及macOS CI
Assets/Upstream/VPet/Core/  当前构建所需的原素材子集
Apple/
  Package.swift            共享Swift包
  Sources/                 PetCore、PetRendering、PetMacInput
  Tests/                   模块回归及原库夹具
  Apps/macOS/              AppKit/SwiftUI应用源码
  iPet.xcodeproj/          可再生成的Xcode项目与共享scheme
  Resources/               AppIcon及忽略的生成资源
  scripts/                 转换、构建、审计及验证工具
  docs/                    导航、规格、对照与交接
  build/、.build/          本机生成目录，不上传GitHub
docs/upstream/             原Windows贡献/开发证据归档
LICENSE、NOTICE             代码许可与来源告知
```

原素材按当前功能保留4616文件、约591MiB；此前移除约433MiB未使用内容，本批为升级动画恢复约13MiB，净减少约420MiB，不降低图片质量。完整Git历史仍保留原件，普通完整克隆不会同步缩小；恢复路径和缓存口径见 [体积说明](Apple/docs/PROJECT-SIZE.md)。原完整Windows源码、README及翻译请在 [上游固定基线](https://github.com/LorisYounger/VPet/tree/1a06c5981330564bab05a098d2d7969a4b119dd3) 或Git历史查阅，不在当前树重复提供。

## 验证与已知限制

```sh
# 转换资源、审计依赖、测试、macOS构建、iOS共享编译与签名检查
bash Apple/scripts/verify.sh
# 资源已生成后，可单独运行共享模块测试
swift test --package-path Apple
```

最近完整自动验证包含 **398项Swift、27项Python**，macOS Release、iOS Simulator共享模块和严格签名检查通过。GitHub自动检查见 [Actions](https://github.com/xufilps/iPet/actions)；日志生成于本机或runner的 `Apple/build/verification/`。自动测试、加速时钟模拟和短时观察不能代替真实使用。

当前范围专注内置萝莉斯和本地养成。多角色与第三方数据型MOD留给未来独立的 **petloader**（尚未开发）；云存档/云同步与联机不做，不列为待补齐能力。本地存档、备份与导出恢复继续保留。

主要未完成项：
- 真实系统睡眠、多显示器、最低系统/Intel及两小时连续运行验收。
- 原生主题/本地化及Windows整档导入。
- 部分原动画变体、工具栏/消息设置、语音与完整调试功能。
- Steam/工坊及C#插件替代仍保留限制；Swift不能直接运行原插件。
- 完整iOS应用、真机验证、Developer ID签名、公证及正式安装包。

完整缺口与阶段标准见 [剩余功能](Apple/docs/REMAINING-FEATURES.md) 和 [路线](Apple/docs/ROADMAP.md)。没有同条件Windows性能对比，不声称更省资源或已完成长期稳定性验收。

## 来源、许可证与贡献

代码遵守 [Apache License 2.0](LICENSE)，原LICENSE全文不变。感谢 LorisYounger、VPet贡献者及虚拟主播模拟器制作组；iPet是派生适配，不是原作者官方Apple版本。修改与署名见 [NOTICE](NOTICE) 和 [ATTRIBUTION](Apple/ATTRIBUTION.md)。

角色、动画与内置图片适用独立授权，不能用Apache代码许可代替。原声明要求告知素材来源、提供原项目链接，并禁止收费分发动画；商业使用须遵循原声明的告知、联系权利人等条件。授权全文保留在 [ANIMATION_LICENSE](Apple/ANIMATION_LICENSE.md)，随应用附带。照片图库不包含在当前源码或应用中。

像素风图标由OpenAI imagegen参考原角色生成，是原形象的新演绎，不宣称独立角色权利或原作者新作；母图及记录见 [Design](Apple/Design/README.md)。

问题与贡献请使用 [Issues](https://github.com/xufilps/iPet/issues) 和指向 `ipet-dev` 的PR，流程见 [CONTRIBUTING](CONTRIBUTING.md)、[支持](SUPPORT.md) 与 [安全报告](SECURITY.md)。详细开发入口见 [文档导航](Apple/docs/README.md)及 [构建说明](Apple/README.md)。

商品价格默认按原版合理阈值修正，可在设置关闭恢复配置原价；当前只有 Shiori v5／v7 两项后续售价改变，既有库存和历史费用不重算。
