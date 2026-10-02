# 阶段3P：两阶段特殊待机与打盹概率退出 — 2026-10-02

依据1a06c598 MainLogic随机分支6、MainDisplay.DisplayToIdel_StateONE/StateONEing/StateTWOing及DisplaySleep：特殊待机ONE开始后按duration10概率循环，退出时Next(2+CountNomal)==0进入TWO（CountNomal初始0，每进TWO+1），否则ONE结束回默认；TWO概率退出后播放TWO C，返回ONE B并重建循环计数。打盹按sleep duration20概率退出，不是固定20秒；人工休息仍强制无限循环。

本批新增纯核心PetSpecialIdle决策（持续/进入TWO/返回ONE/结束）与注入随机，新增特殊渲染动作族和两个Graph状态/阶段/变体；随机分支6调用ONE，无当前状态资源回普通待机，Ill不借非Ill素材。TWO C结束只返回ONE循环、不触发基础完成；人工动作/结束/隐藏等清除旧内部返回。打盹复用概率计数，不改state.resting；手动休息保持无限，二者清楚区分。

范围：Core特殊决策/Autonomy、转换器与可选循环字段、PetScene阶段链/AppModel调用、测试及文档。先固定特殊切换、计数增加、概率边界、打盹vs强制休息、动画返回/打断测试失败，再实现。保存v2/清单v3/文本v1不变；完整Swift/Python/macOS/iOS、工程重复生成、原README/LICENSE及文档检查。原调度、扩展随机插件、活动中互动与逐循环变体重选仍留后续；真实输入/多屏/睡眠与压力最后。

回滚同步源码和转换器重建，无保存降级；正式存档退出备份。仅视觉特殊待机不修改养成，清单可选idleLoopLimit接受fidget/specialIdle/sleep，旧清单可用默认duration。
