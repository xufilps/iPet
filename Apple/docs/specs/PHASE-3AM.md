# 阶段3AM：原生活动计时显示模式

原版依据：1a06c598 WorkTimer.xaml.cs.DisplayType、SwitchState_Click、ShowTimeSpan，已用/剩余/收益/收起四种循环；秒<90、分钟<90，否则小时，时间显示1位小数。目标是让现有随宠工具栏有对应原生操作，暂停/继续/停止入口始终保留。

实现：只读ActivityFeedback增加已用有效时间；纯Swift模式枚举/读数映射，工具栏会话内切换按钮。时间依据session.elapsedSeconds，暂停不增加、退出/睡眠不补算；收益只展示已有earned，保留2位小数原生精度（原DisplayType2为整数）。未知目录时已用可显示、剩余未知不伪造，收起隐藏详细进度/读数不禁用停止。模式只在当前工具栏实例保留，非宠物JSON及本机永久偏好。

文件：Sources/PetCore/ActivityFeedback.swift、PetActivityTimer.swift；Tests/PetCoreTests/PetActivityTimerTests.swift；Apps/macOS/PetToolbarWindow.swift；README/差异/交接/路线。

步骤：先写时间单位边界、模式循环、暂停/未知目录/异常时间、收益单位和收起测试并观察失败；实现只读模型与UI；完整Swift/Python/macOS/iOS/签名/工程验证；独立6.1-sol审查与可操作界面核对，真实独立工具栏仍需用户验收。无新资源、事务、权限或保存迁移。

风险：把墙钟误当活动有效时长会产生离线补算；只取既有session值。切换显示不能改变收益/暂停状态。原WorkTimer整体样式、统计小标和完成事件体系仍非完全迁移。本批不新增自动语音/气泡回放，不改变已存在的结束反馈。回滚代码重建即可，存档v9与本机配置不变。压力、睡眠、多屏继续延后。

状态：规格/计划检查点，尚未实现。
