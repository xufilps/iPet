# 阶段3X：活动中的随机动作与返回 — 2026-10-02

原IsIdel包含Default和Work且非按压，EventTimer在Work动画时随机范围为2*max(20,InteractionCycle-CountNomal)+20；DisplayToNomal按WorkingState回NowWork显示。当前只在idle且没有会话触发，本批允许活动基础动画中的工作/学习/娱乐触发，但暂停/结束过渡/瞬时动作/休息/隐藏/输入仍不触发。

PetAutonomy资格和poll新增working上下文，原随机倍率保留；AppModel按当前activity显示且有效活动传入。已有动画完成回调从最新模型恢复基础，随机动作不设置resting、不改activity，时钟/收益继续；结束/暂停后不得恢复旧活动，不重复发奖金。基础idle计数仍只计默认动画，活动循环不假装成闲置累计。

新增核心资格/倍率边界与渲染+引擎衔接测试，验证打盹期间活动进度/收益继续、完成后恢复当前graph、活动已结束不复活。完整回归/双平台/工程/许可后提交，保存v4和素材不变。扩展随机插件池/旅行等未迁移，真实活动中移动/侧挂与输入、压力最后；回滚源码重建，不降级存档。
