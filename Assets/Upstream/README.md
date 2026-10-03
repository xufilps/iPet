# 原作资源子集（构建输入）

`VPet/Core/` 保留当前macOS构建实际依赖的原素材与配置，来源为 [LorisYounger/VPet @ 1a06c598](https://github.com/LorisYounger/VPet/tree/1a06c5981330564bab05a098d2d7969a4b119dd3/VPet-Simulator.Windows/mod/0000_core)。目录整理时曾原样迁移6495文件；本次按转换器来源清单裁剪为4534文件、578.05MiB，保留文件原字节不变。保留4393动画帧、实际目录图片/文本/养成配置及info/icon元数据及9份进食分层配置。

删除当前未使用的图库ZIP及定义、Windows主题/字体/语言、未选用动画和其它未依赖内容，共1961文件、433.28MiB。它们仍在Git历史和上游，不代表原作删除这些内容，也不代表iPet已兼容原完整目录。`Apple/scripts/audit_resources.py` 读取三类转换来源清单，核对来源清单内哈希、12份额外元数据/分层配置的存在/跟踪状态及多余跟踪资源；新增动作必须先更新转换器及其规格，再纳入对应来源文件。

转换器生成 `Apple/Resources/PetAssets/`，该目录不提交。原始素材的裁剪不改变当前151组合、4393帧、118物品及既有文本；空目录重新生成的全部输出须与裁剪前逐字节一致。当前清单不是通用MOD接口，不修改原PNG或压缩质量。

需要找回未选用资源时，从裁剪前提交 `4c32d54d` 恢复对应 `Assets/Upstream/VPet/Core/` 文件；浅克隆须先获取该提交，或到上游固定基线原 `VPet-Simulator.Windows/mod/0000_core/` 路径取回。请勿直接恢复整个目录后跳过依赖审计。完整历史体积不会因裁剪立即缩小，见 [体积说明](../../Apple/docs/PROJECT-SIZE.md)。

代码许可不代替角色/图片许可，见 [动画授权](../../Apple/ANIMATION_LICENSE.md) 和 [来源](../../Apple/ATTRIBUTION.md)。图库不再随当前源码树提供；将来引入素材必须单独确认来源、授权和分发权利。
