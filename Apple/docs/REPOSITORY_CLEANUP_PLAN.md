# iPet 仓库精简 — 2026-10-01

用户要求从当前GitHub源码树删除原C#工程，仅保留来源说明；实机验收暂缓。执行范围为VPet-Simulator.Core、Tool、Windows.Interface、VPet.Solution、VPet.sln及Windows目录内非mod文件。保留Windows/mod/0000_core：Swift资源转换器依赖其PNG与LPS配置；本轮不迁移素材路径或修改养成接口。保留原图标、Apache LICENSE、署名、独立素材授权和根README的原文后缀。删除仅影响当前树，不重写Git历史；不清理用户未跟踪文件。

差异矩阵原源码链接改为原仓库固定基线1a06c5981330564bab05a098d2d7969a4b119dd3，当前README说明源码不再随仓库提供，历史文档注明其描述旧交付。文档中的旧README链接与构建方式属历史原文，应到上游阅读，不代表iPet当前结构。自动验证执行16测试、资源转换、macOS构建、iOS共享模块编译、工程生成/图标和原README/LICENSE完整性；暂缓实机不代表实机通过。

回滚使用Git revert恢复删除提交，素材和正式存档不修改；正常提交推送origin/main并核对远端SHA。完成后提交交接。其它优化在确定具体范围后另按Superpowers设计流程推进，不在仓库清理中混入新养成系统。
