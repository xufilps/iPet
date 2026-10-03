# 阶段3AA：提起阶段变体与关联审计 — 2026-10-03

沿用1a06c598 MainDisplay.DisplayRaising/Display(name,phase,type)和GraphCore.FindGraph依据。原版沿回调Graph名尝试同名同类型阶段，无匹配则按类型回退；内置当前Raise目录仅Raised_Dynamic和Raised_Static，不能据通用接口宣称有未复现的第三方特殊动作。动态Nomal已有两个Single变体；静态Happy有C_Happy/C_Happy_2，但转换器此前仅选第一个。

本批范围是导出静态提起各阶段候选，并按注入随机源选择放下变体；保持动态三次/静态悬挂、原锚点和移动阈值。先提交规格，再写转换/渲染回归并观察失败，再实现；不新增动作类型/存档格式或无来源的特殊动作。第三方Graph名称兼容仍归数据MOD接口研究。

验证Happy放下两候选都能到达、状态/阶段正确、缺资源回退和打断回归；全Swift/Python与macOS/iOS共享构建。原许可、README后缀和ipet-dev工作流保持；回滚本批后重新转换/构建，不改宠物v7。真实放下观感和压力仍留后。


## 交付记录

2026-10-03完整verify.sh通过：166核心+68渲染+6macOS按键=240 Swift，20 Python，macOS Release/ad-hoc严格签名与arm64 iOS Simulator共享模块编译；日志在忽略目录Apple/build/verification/phase3aa-ab.log及分项日志。原README7775字节/原LICENSE完整、重复生成工程一致、改动文档链接与diff检查通过。静态放下回归撤去结束变体选择后只出现一组并失败，恢复后两组通过；播放节奏先观察缺模型失败，再实现5项固定时间/Unicode/取消/边界回归。

资源当前147组合、4269帧约558.0MiB，新增21帧约2.9MiB；缓存策略不变，无性能/实机观感结论。6.1 Sol只读独立审查未发现重要缺陷，未启动应用；长文本气泡仍可能受屏幕尺寸裁剪，沿用已有非交互文本布局并保留实机缺口。存档v7保持，回滚本批重建资源即可，正式数据未修改。
