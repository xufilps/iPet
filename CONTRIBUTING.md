# 为 iPet 贡献

iPet 是 VPet 的 Swift 原生适配，当前维护入口为 `ipet-dev`；`main` 仅同步上游，不接受 iPet 功能修改。请向 `ipet-dev` 提交 Pull Request。原 Windows 项目的贡献指南逐字节归档于 [docs/upstream](docs/upstream/README.md)，其 Steam/C#/WPF 流程不适用于本工程。

## 开发环境与入口
需要 macOS 26+、Xcode 26+ / Swift 6 和系统 Python 3；共享模块最低支持iOS／iPadOS 26。共享包位于 `Apple/Package.swift`，macOS 应用位于 `Apple/Apps/macOS/`，iOS应用位于 `Apple/Apps/iOS/`；完整验证还需安装iOS26+ iPhone Simulator runtime，iOS模型测试使用独立临时存档；目录职责见 [结构说明](Apple/docs/REPOSITORY-STRUCTURE.md)。无需 .NET 即可构建应用；`legacy_lps_oracle` 仅用于生成固定版本原库证据。

```sh
git switch ipet-dev
git switch -c codex/your-change
swift test --package-path Apple
bash Apple/scripts/verify.sh
```

先同步远端，再从 `ipet-dev` 开功能分支。SwiftPM 的 Sources/Tests 按目标分开；不要把 AppKit/SwiftUI 窗口代码放入纯 Swift 的 PetCore。PetRendering 只负责呈现，养成变更走 PetCore。使用 Swift 6 的并发检查；本批仅配置后续编辑习惯，不进行全仓格式化。

## 修改与验证
开始前核对 [剩余功能](Apple/docs/REMAINING-FEATURES.md)、[行为对照](Apple/docs/BEHAVIOR.md) 和对应规格。复杂修改先记录范围、源码依据、存档兼容、验证与回滚。修改养成规则需固定输入/时钟/随机源回归；目录或构建修改需验证入口和生成项目。`verify.sh` 检查仓库结构、Python/Swift测试、macOS Release、iOS共享模块及自用签名；日志在 `Apple/build/verification/`。CI结果不能代替真实睡眠、多屏、输入或两小时验收。

原始资源在 `Assets/Upstream/VPet/Core/`，转换结果在忽略目录 `Apple/Resources/PetAssets/`。更改Xcode配置时先改 `Apple/scripts/create_project.py`，重新生成后提交共享项目与scheme；不要手工维护与生成器冲突的项目设置。不要提交用户存档、凭证、个人Xcode状态、生成纹理包或构建产物。

## Pull Request 内容
说明解决的问题、可观察行为、验证结果与未验证部分；涉及存档时列版本变化、备份和回滚方法。新增素材说明来源、授权和是否可分发。提交前运行 `git diff --check`；避免把无关格式化与功能修改混为同一PR。

原 `LICENSE` 不改，保留适用的原作者署名、NOTICE及素材授权。原README在Git历史/上游可查，当前根README以iPet实际行为为准。代码采用 Apache 2.0，原角色/动画另有授权，见 [素材授权](Apple/ANIMATION_LICENSE.md)；不能用代码许可代替图片分发许可。安全问题遵循 [SECURITY.md](SECURITY.md)，一般使用问题见 [SUPPORT.md](SUPPORT.md)。
