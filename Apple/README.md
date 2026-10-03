# iPet Apple 工程 · v0.2.0

macOS 26+原生桌宠，Swift 6共享核心及SpriteKit动画模块最低支持iOS／iPadOS 26。当前包含macOS桌宠和iOS应用内养宠源码/自用Simulator构建，尚无正式签名、公证安装包或真机验收。iOS固定角色与Liquid Glass界面设计见[首版规格](docs/specs/PHASE-6A-IOS.md)。当前功能和验收以 [交接](docs/HANDOFF.md) 为准；目录职责见 [工程结构](docs/REPOSITORY-STRUCTURE.md)。

## 构建和启动
需要macOS26+、 Xcode 26+（Swift 6）、Python 3和本仓库原始素材。没有第三方Swift依赖，不需要.NET、Steam或Windows工具。首次克隆包含较大原素材；只转换选用动作，原素材在 `../Assets/Upstream/VPet/Core/`。

从仓库根目录运行：
```sh
bash Apple/scripts/build.sh
open Apple/build/Build/Products/Release/iPet.app
```

也可进入 `Apple/` 执行 `./scripts/build.sh`。Xcode打开 `Apple/iPet.xcodeproj`，选择共享 `iPet` scheme；构建前自动转换素材。命令行脚本创建自用ad-hoc签名，不构成Developer ID签名、公证或公开发行包。项目由 `python3 Apple/scripts/create_project.py` 生成，配置修改须同步生成器；本机用户状态不提交。

## 共享模块与应用边界
```sh
swift test --package-path Apple
bash Apple/scripts/verify.sh
```

`Package.swift` 是共享库唯一manifest，`Sources/PetCore`为纯Swift养成/保存，`Sources/PetRendering`为SpriteKit，`Sources/PetMacInput`为平台输入适配；对应回归在 `Tests/`。AppKit/SwiftUI应用源码独立放在 `Apps/macOS/`，由Xcode构建。生成的 `Resources/PetAssets/` 不提交；图标资源目录和 [母图来源](Design/README.md) 已提交。

`verify.sh` 验证目录入口、原LICENSE和保留的上游归档完整性、文档链接、生成项目一致性，运行28项Python、408项共享Swift和8项iOS模型测试，构建macOS Release与iOS Simulator应用、以iOS26最低目标交叉编译共享模块并验证签名。日志在 `build/verification/`。本次本机通过不代表GitHub runner已通过；CI只启动隔离模型测试的Simulator宿主，不进行真实触摸验收、修改用户存档或执行压力测试。

## 数据与恢复
正式存档仍为 `~/Library/Application Support/VPetApple/`，当前JSON v9；主档 `pet.json`、上一份有效档 `pet.previous.json`。每60秒、关键互动、睡眠和退出保存。损坏原件保留并尝试备份，未来版本阻止覆盖；读取旧v1…v8后，首次升级写入前保留独立旧版本原件。

回滚旧程序前退出并备份整个目录，移开v9主/previous，再用对应旧版本的 `pet.vN-before-upgrade-*.json` 副本恢复主档；不能修改版本头冒充降级。本次目录整理不改变存档版本或位置，回滚代码无需恢复档案。Windows LPS目前只有结构、宠物、库存、统计及hash只读预览，尚未开放整档导入。

## 使用、许可与验证边界
菜单栏提供显示/隐藏、位置恢复和功能入口；现有中文原生面板、13项活动、118项物品、套餐/日程及本地统计见根 [README](../README.md)。窗口不抢桌宠键盘焦点，透明区按帧alpha穿透；真实睡眠、多屏、最低系统/Intel和两小时观察仍待最终验收。

[署名](ATTRIBUTION.md)、[原动画授权](ANIMATION_LICENSE.md)、根LICENSE与NOTICE随应用附带。代码Apache 2.0不替代角色/动画授权；不执行C#插件。贡献流程见 [CONTRIBUTING](../CONTRIBUTING.md)，完整差异/缺口/路线见 [文档导航](docs/README.md)。当前继续推进本地内置角色体验，最近补齐升级通知与动画。

当前原素材按实际依赖保留693.13MiB，含升级动画及本批恢复的活动变体；体积边界、浅克隆和缓存恢复见[PROJECT-SIZE](docs/PROJECT-SIZE.md)。

GitHub不会显示Apple/build：应用与日志在本机执行脚本后生成，当前可运行产物为iPet.app；旧VPetApple.app已清理，历史用户存档目录名仍保留。根README已改为当前项目说明，原README/翻译转为上游及Git历史查阅。

## iOS应用入口

Xcode共享scheme `iPet-iOS`，命令行 `bash scripts/build-ios.sh`；隔离模型测试 `bash scripts/test-ios.sh`。固定角色与Liquid Glass界面复用规则，不含自主移动。运行、真机签名、存档保护和差异见[iOS说明](docs/IOS.md)。
