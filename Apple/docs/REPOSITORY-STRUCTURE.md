# 仓库与Swift工程结构

```text
.github/                   GitHub问题/PR模板及macOS自动检查
Assets/Upstream/VPet/Core/  当前所需原作素材子集（只读构建输入）
Apple/
  Package.swift            共享Swift包唯一manifest
  Sources/
    PetCore/               养成、存档、目录与兼容预览；无平台UI依赖
    PetRendering/          SpriteKit动画与资源解释
    PetMacInput/           macOS输入适配
  Tests/                   对应模块测试及固定原库夹具
  Apps/macOS/              AppKit窗口、SwiftUI面板和生命周期
  iPet.xcodeproj/          可再生成项目及共享scheme
  Resources/               提交的AppIcon与忽略的PetAssets生成包
  Design/                  图标母图和来源记录
  scripts/                 转换、工程生成、构建和验证工具
  docs/                    当前导航、交接、规格及历史证据
  build/、.build/          本机生成输出（忽略）
docs/upstream/             原Windows文档/配置的原字节归档
README.md                  当前iPet入口，原README通过上游/历史查阅
CONTRIBUTING.md             iPet贡献约定
LICENSE、NOTICE             原代码许可与修改署名
```

`Apple/` 是SwiftPM包根，标准 `Sources/<Target>` / `Tests/<Target>Tests` 均相对于该目录；根目录不重复定义manifest。macOS应用由Xcode构建，不作为共享包库目标。当前无iOS App目录，避免将目录存在误当成已交付应用。

从仓库根目录运行 `swift test --package-path Apple`、`bash Apple/scripts/build.sh` 或 `bash Apple/scripts/verify.sh`；也可在Apple下使用原命令。工程配置以 `scripts/create_project.py` 为源，修改后运行生成器并提交项目及scheme；本机用户状态不提交。开发用.NET Oracle保留在scripts中，不进入运行时或CI依赖。

原素材由转换器按需挑选，不预载全部目录，生成输出不提交。原作来源及授权见 [素材索引](../../Assets/Upstream/README.md)；已归档的Windows指南不再占用根贡献入口。`.editorconfig` 只约束后续编辑，不批量格式化现有源码或原文。GitHub CI使用macOS runner运行与本机相同的自动验证；不替代真实UI/睡眠/多屏/长期运行，也不构成公证发行。

本次只移动和配置，不改JSON v9或 `Application Support/VPetApple`；回滚整理提交即可，用户档案无需恢复。`main` 为上游镜像，开发及PR目标为 `ipet-dev`。

资源目录已按当前转换依赖裁剪，未使用素材可从历史/上游找回，见[体积与恢复](PROJECT-SIZE.md)。
