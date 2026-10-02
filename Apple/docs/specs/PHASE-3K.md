# 阶段3K：顶部爬行与斜向下落 — 2026-10-02

依据1a06c598 vup.lps move及GraphHelper.Move.Display/Triggered/Checked：顶部左右LocateTop150、TriggerTop<=100、方向侧距离>=200、Check侧>=100、速度8每125ms、Distance10；下落左右Trigger底/方向侧>=200、Check底/方向侧>=100、SpeedX±14、Windows SpeedY10每125ms、Distance7，Happy/Nomal/Poor允许，Ill拒绝。macOS Y轴反转，顶锚点为visibleFrame.maxY-height+150×缩放。

扩展既有PetClimbPlan为wall/top/fall，复用渲染climb动作族和Graph精确选择，避免保存字段变化。开始完成才定位/位移，top可部分出屏，fall从当前位置斜向下降；位移按delta上限250ms且在100安全边界停止，斜向使用同一比例限制，避免改变向量。初始扩展原50%特殊移动分支候选，当前阶段仍不是完整原抽池；循环退出尝试同类型同向自身，完整兼容衔接另批核对。范围固定开始屏幕，取消/结束/保存沿安全回正，点击和拖动保持现有处理。

新增四Graph各状态与阶段变体；改动PetClimbPlan、AppModel选择与继续、转换器及渲染/几何测试和文档。先写原参数、阈值、负坐标、轴向、边界和状态拒绝测试，失败后实现；完整Swift/Python/macOS/iOS共享模块、原README/LICENSE、工程重建与文档链接验证。真实顶部裁剪/输入、多屏/睡眠与压力最后，不当编译等于实机通过。

保存v2/动画v3/文本v1不变，回滚同步源码和转换器再重建；正式存档先退出备份，不降级保存。后续完整原移动池/兼容、动态提起、随机待机按依赖推进，当前不实现跨屏与移动区域设置。
