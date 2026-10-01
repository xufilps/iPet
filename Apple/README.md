# iPet · v0.1.0

VPet 的 Swift 原生适配：macOS 14+ 桌宠，纯 Swift 养成核心及共享 SpriteKit 动画模块支持 iOS 17+。本版交付 macOS 应用，尚未包含 iOS 应用界面。

## 构建和启动

需要 Xcode 16+（Swift 6）及 Python 3，无第三方 Swift 依赖。仓库须包含原版 `VPet-Simulator.Windows/mod/0000_core/pet/vup` 素材。

```sh
cd Apple
./scripts/build.sh
open build/Build/Products/Release/iPet.app
```

也可先运行 `python3 scripts/convert_assets.py`，再用 Xcode 打开 `iPet.xcodeproj`、选择 `iPet` scheme 运行。Xcode 每次构建会重新转换内置素材；无需配置 Steam 或运行 Windows mklink。命令行脚本创建自用 ad-hoc 签名，并不构成 Developer ID 签名、公证或公开发行包。

## 使用

菜单栏 🐾 提供状态与设置、投喂、饮料、休息、显示/隐藏、重置位置和退出。点击头部或身体进行抚摸，拖动角色会播放提起动画，右键角色打开面板。设置窗口支持 ⌘,，退出支持 ⌘Q。窗口默认 280 点，可调整到 150–500 点；透明区域按当前帧 alpha 采样穿透，轮询频率 30 Hz。拖动期间保持鼠标捕获，桌宠窗口不能成为键盘主窗口；打开设置时会正常激活应用。

免费面包、饮料为本版适配，不等同原版商店物品。休息与投喂可恢复状态；无离线扣减，退出和系统睡眠期间不补算养成。隐藏桌宠暂停渲染并释放纹理，应用仍在运行时养成继续。自主移动限定在显示器可见区域，首版不含爬墙、跨屏自主漫游或边缘隐藏。

## 文件与恢复

- `Sources/PetCore`：养成公式、输入命令、时钟/随机源、状态快照和版本化 JSON 保存。
- `Sources/PetRendering`：资源清单、逻辑坐标、逐帧时长、动作阶段、图层和缓存。
- `Sources/iPetMac`：AppKit 桌宠、SwiftUI 状态面板及菜单/生命周期。
- `Resources/PetAssets`：构建生成并忽略的素材，仅包含选用动作；源码仍在原版目录中。

正式存档位于 `~/Library/Application Support/VPetApple/`，主文件为 `pet.json`，上一份有效存档为 `pet.previous.json`。每 60 秒、关键互动、睡眠和正常退出保存。损坏主文件会保留为 `pet.corrupt-UUID.json` 并尝试加载备份；损坏备份在写入前另行保留。未来版本主文件或备份阻止保存；加载失败的会话明确提示并停止写入。需要手动恢复时先退出应用并复制整个目录，再用确认有效的备份替换主文件；不要删除未来版本或损坏证据来尝试“修复”。大小、位置和自主移动偏好存于应用 UserDefaults。

本版不读取 Windows LPS 存档，不支持第三方 MOD、C# 插件、Steam、云同步、AI 对话或自动启动。代码和素材来源见 [ATTRIBUTION.md](ATTRIBUTION.md) 与 [ANIMATION_LICENSE.md](ANIMATION_LICENSE.md)，这些文件及 Apache LICENSE 随应用附带。

## 验证

```sh
./scripts/verify.sh
# 两小时真实渲染观察，前台保留桌宠和设置窗口；使用隔离测试存档
python3 scripts/soak.py --seconds 7200 --output build/soak-2h.json
```

`verify.sh` 转换素材、运行核心/渲染测试、构建 macOS 应用并对共享模块做 iOS Simulator 交叉编译。测试中的两小时养成模拟使用注入时钟，不代表真实运行两小时。`soak.py` 按墙钟时间持续切换动作/状态、隐藏恢复、模拟生命周期暂停恢复，记录每 5 秒 CPU 和 RSS；它不能替代真实系统睡眠或多显示器热插拔。

当前验证证据和剩余实机检查见 [docs/HANDOFF.md](docs/HANDOFF.md)，行为区别见 [docs/BEHAVIOR.md](docs/BEHAVIOR.md)。回滚只需回退 Apple 相关提交；原 C# 项目未修改，用户存档不应随代码回滚删除。

## 图标与后续还原

像素风 AppIcon、母图及导出说明见 [Design/README.md](Design/README.md)；资源目录通过工程生成脚本同步接入。完整原版能力矩阵见 [UPSTREAM_COMPARISON.md](docs/UPSTREAM_COMPARISON.md)，先还原 macOS 玩法、后扩展 iOS 的阶段门槛见 [ROADMAP.md](docs/ROADMAP.md)。本轮仅修改图标配置与文档，不改变养成或存档。
