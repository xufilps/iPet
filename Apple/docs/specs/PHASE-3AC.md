# 阶段3AC：离线说话表情与气泡衔接 — 2026-10-03

延续已批准的原版还原路线；依据1a06c598 MainLogic.Say(SayInfoWithOutStream)、Main.xaml.cs默认SayRndFunction及MessageBar.ShowTimer_Elapsed。默认从Say类型随机选择Graph；仅Default动画时播放A，结束A后显示气泡并循环B；文字队列空的下一tick停止输出、播放Say C并恢复正常，气泡继续按标点停留/淡出。非Default只显示文字，不抢活动/休息/人工动作。GraphCore.FindGraph禁止Ill回退到非Ill，因此生病只显示文字。

资源为Say/Self、Serious、Shining、Shy，目录未写状态时原GraphInfo默认为Nomal，B_1/2/3为同阶段随机变体。本批转为say.self/serious/shining/shy，保留A/B/C和各阶段候选；新增纯视觉say动作，不改JSON v7。只在待机且无鼠标按压时启动，随机选择可用完整家族；缺资源直接气泡并诊断。A结束回调只触发一次，打断清除，隐藏/睡眠不重放；文字开始停留时仅结束仍在say的动画，不能结束新活动。渲染错误仍显示本地文字，旧回调不得复活。

实现顺序：提交本规格；写转换/渲染阶段/回调/打断/Ill/缺资源与文字结束事件回归并观察失败；实现资源与SpriteKit、PetSpeechWindow及AppModel衔接；完整验证、独立6.1 Sol审查、文档和推送ipet-dev。原main不改、原README/许可保留；不包含选择式聊天/语音/网络/消息队列或强制讲话接口。

真实表情/长文本/焦点仍待实机，不以测试替代；资源仅增加本批必要PNG并沿用缓存。回滚本批代码、重新转换构建即可，无存档升级；正式数据不修改。
