# 阶段3L：完整内置移动候选与双轴衔接 — 2026-10-02

依据1a06c598 vup.lps全部16条move、MainDisplay.DisplayToMove随机排列后取首个Triggered（等价于从有效候选均匀选择）、GraphHelper.Move.GetCompatibilityMove：X/Y双方非零时同向+1反向-1，合计>=0允许，再通过状态/距离触发，可包含自身；退出/边界以Next(5)<=1尝试衔接。原walk Mode12支持Nomal/Poor，Poor同时具有普通走和慢走，不能只选慢走。

本批统一已迁移walk/crawl/wall/top/fall候选，不再初始50%特殊移动或步行/爬行各半。新增纯渲染层PetMovementChoice组合两种计划、向量评分及完整有效抽池；补Poor普通走候选，保留16条原配置权重（同Graph左右墙上/下为独立候选）。循环/安全边界40%尝试全池方向评分衔接；没有候选结束。速度Y使用macOS轴，同向关系与原Windows轴同时翻转等价。所有移动锁定开始屏幕，部分越边可衔接，不瞬间回正改变候选，结束/取消才恢复安全位置。

窗口策略仍采用visibleFrame和100安全截停，原自动回正、全部MoveEnd侧挂、跨屏/移动区域设置未宣称还原；初始调度频率/随机源不与.NET序列等同。存档、资源版本和已选PNG不变。先写池、Poor、边缘转墙、双轴评分与反转拒绝测试并记录失败，随后实现、完整Swift/Python/macOS/iOS、工程一致性和原README/LICENSE检查，文档与Git检查点推送。

范围：PetWalkPlan/PetClimbPlan公开向量、PetMovementChoice、AppModel统一选择、测试与文档；不改养成/保存。回滚源码即可重建，无保存降级，正式存档先退出备份；真实多屏/裁剪/睡眠和压力仍留最后。本规格为推进依据，不另请求已授权范围批准。
