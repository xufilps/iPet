# iPet 仓库结构整理计划 — 2026-10-03

## 范围与约束
将 GitHub 协作入口、Swift 共享包、macOS 应用、原始素材及上游文档明确分开。此批只整理开发结构和自动验证入口，不改变养成、JSON v9、用户数据目录、应用版本或功能。不启动后续功能阶段；交付后停止。原 LICENSE 保持字节一致，根 README 的原文 7775 字节后缀不变，原资源只移动不修改，main 上游镜像不变。

## 目标结构
- 根目录：iPet README、贡献指南、许可证/NOTICE、Swift/Python 编辑及忽略配置；`.github/` 提供问题表单、PR 模板与 macOS CI。
- `Apple/Package.swift`、`Apple/Sources/<Target>`、`Apple/Tests/<Target>Tests`：保持现有 SwiftPM 标准布局及共享模块边界。无需为了根目录 manifest 增加第二份包定义。
- `Apple/Apps/macOS/`：仅 AppKit/SwiftUI 应用源码，与共享库目标分离；Xcode 项目和既有脚本入口仍在 Apple 下。
- `Assets/Upstream/VPet/Core/`：原始内置素材/config，只作为构建输入；`Apple/Resources/PetAssets/` 仍为忽略的生成输出。
- `docs/upstream/`：逐字节归档原贡献文档、翻译及二次开发文档，明确其 Windows 历史范围；原文引用的根翻译入口保留链接页。
- `Apple/docs/README.md`：当前文档导航，阶段规格/历史继续保留原路径，避免为美观批量改写历史证据。

## 实施顺序
1. 先提交计划检查点，记录素材及上游文件的路径/SHA256基线。
2. 移动素材与平台源码、归档旧文档；同步转换器、测试数据源、工程生成器及当前指南。清理仅针对已跟踪内容，不删除本机未跟踪恢复文件。
3. 补充贡献/支持/安全报告说明、问题/PR模板、macOS CI及结构验证脚本；替换仅适用于C#的编辑配置和忽略规则，保留开发用.NET Oracle的输出忽略。
4. 运行资源/Swift全套、macOS Release、iOS共享模块、签名；对比资源移动前后SHA256、原README/LICENSE、生成工程一致性及当前文档链接。独立6.1-sol审查一次，必要修复后重新验证。
5. 提交并合并回ipet-dev，推送该分支并核对远端；main不动，交接记录区分本机通过与GitHub CI尚未运行。

## 验证、风险与回滚
目录迁移风险集中于默认素材路径、工程引用、相对文档链接及CI工具链。新增结构检查用于防止入口失联，不为纯文件移动增加养成规则测试。CI只运行自动检查，不启动UI、不要求签名证书、不执行两小时压力；第三方Action固定提交，权限只读。原素材SHA256必须完全一致；未跟踪本机文件不纳入提交。回滚此批提交/目录移动即可，存档无需降级；原Windows资料可在归档或上游固定基线查阅。

依据：[SwiftPM目标布局](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)、[GitHub社区模板](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates)。Apple为包根并不违反SwiftPM布局；此次不宣称存在统一强制的GitHub工程目录标准。
