# 阶段3AC：离线说话表情与气泡衔接 — 2026-10-03

延续已批准的原版还原路线；依据1a06c598 MainLogic.Say(SayInfoWithOutStream)、Main.xaml.cs默认SayRndFunction及MessageBar.ShowTimer_Elapsed。默认从Say类型随机选择Graph；仅Default动画时播放A，结束A后显示气泡并循环B；文字队列空的下一tick停止输出、播放Say C并恢复正常，气泡继续按标点停留/淡出。非Default只显示文字，不抢活动/休息/人工动作。GraphCore.FindGraph禁止Ill回退到非Ill，因此生病只显示文字。

资源为Say/Self、Serious、Shining、Shy，目录未写状态时原GraphInfo默认为Nomal，B_1/2/3为同阶段随机变体。本批转为say.self/serious/shining/shy，保留A/B/C和各阶段候选；新增纯视觉say动作，不改JSON v7。只在待机且无鼠标按压时启动，随机选择可用完整家族；缺资源直接气泡并诊断。A结束回调只触发一次，打断清除，隐藏/睡眠不重放；文字开始停留时仅结束仍在say的动画，不能结束新活动。渲染错误仍显示本地文字，旧回调不得复活。

实现顺序：提交本规格；写转换/渲染阶段/回调/打断/Ill/缺资源与文字结束事件回归并观察失败；实现资源与SpriteKit、PetSpeechWindow及AppModel衔接；完整验证、独立6.1 Sol审查、文档和推送ipet-dev。原main不改、原README/许可保留；不包含选择式聊天/语音/网络/消息队列或强制讲话接口。

真实表情/长文本/焦点仍待实机，不以测试替代；资源仅增加本批必要PNG并沿用缓存。回滚本批代码、重新转换构建即可，无存档升级；正式数据不修改。


审查修正：开始段按压丢弃回调时同时进入C，防止文字未出现而B无限循环；保留原聊天冷却，取消不是重新发消息。tick先采样低状态提醒，再重新根据最新动作判断自主行为资格，防止同一tick使用旧待机资格覆盖Say A。前者由取消后C/最终idle断言回归，后者由Say前后资格集成检查与AppModel接线审查确认；真实输入仍未验。


## 验证与交付记录

2026-10-03最终verify.sh通过：167核心+71渲染+6macOS按键=244 Swift，21 Python，macOS Release/ad-hoc严格签名及arm64 iOS Simulator共享编译。日志在忽略目录Apple/build/verification/phase3ac.log及分项日志；宿主仍为第五阶段交接记录的arm64环境，部署目标macOS14/iOS17。新增转换检查先观察无Say清单失败；核心事件/渲染回调撤去后断言失败，恢复后通过；开始取消断言先验证旧实现仍为A/B且不回idle，再修复通过。

6.1 Sol独立只读审查指出开始取消无限循环和同tick自主行为抢占两项，均修复并经复查确认；没有其它可操作问题。审查未运行应用/并行构建。原README7775字节/原LICENSE、重复工程生成、本地链接和diff完整性通过。新资源当前151组合4393帧约576.9MiB，新增4组合124帧约18.9MiB，无长期资源/实机结论。

宠物JSON v7未变，正式数据与未跟踪原C#文件未修改；GitHub默认展示ipet-dev，main保持33293343。后续优先按源SmartMove/MoveArea定义设计原生移动范围，再补选择式文本/完整消息设置与数据兼容；压力/iOS应用/发行继续留后。
