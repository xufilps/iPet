# 阶段5D：任务套餐签署与续费 — 2026-10-02

依赖5C倍率。来源1a06c598 ScheduleTask.Package/PackageFull/AutoRenew、MainWindow.cs1976规范化、winWorkMenu签署/替换退款及续费开关、SchedulePackage.lps14条。数据构建前转换进gameplay.json，含源哈希，非运行时LPS或通用MOD兼容。PetCatalog可选packages字段兼容旧目录，纯Swift定义/已签套餐模型与规则；PetState可选工作/学习套餐，JSON v6升级独立保留v1...v5迁移主档/加载源，future v7拒绝，未知套餐ID保留不可续费。

规范化忠实PackageFull.FixOverLoad：Duration<1→1、Price<0→1、LevelInNeed<1→1.25、Commissions<0→.2，use三项有符号1.5次幂与价/级系数，除sqrt(Duration)<10→(.2,1.25,1,7)。签署价格=定义Price*(200*选择等级-100)，授权等级截断选择等级/LevelInNeed，到期=可注入墙钟+Duration天。原UI15级解锁、选择上限floor(Level/5)*5；原生5级步进（原高等级动态步进不逐字重建），核心签署要求15...100000、5的倍数且不超当前等级。手动余额>=全价，不能先用退款满足支付。活跃替换必须显式确认；退款按原公式remainingDays/2>0.5时，用旧定义及已获授权等级重新报价乘(Duration-remainingDays/2)/Duration，越界归零；未知旧定义退款0并说明，不触发原版空引用。

续费只在显式检查、切换续费开关及后续日程启动发生，绝不每tick或启动自动离线扣款。过期且AutoRenew=true、原定义存在、余额严格大于新价才续；按原已获授权等级重新报价导致等级降低，新套餐AutoRenew默认false（一次续费关闭开关）。两个套餐按工作后学习顺序共享余额。到期本身不扣养成、不停止手动活动；套餐将作为后续日程条件。本基线所有Commissions引用仅声明/构造/规范化/展示，未找到收益扣除实现，保留和展示原工作抽成/学习1-Commissions信息，不自行将其乘到手动收益。

新增套餐页或活动页折叠区域显示定义、签署选择/费用/授权等级/期限、当前合同/过期、续费开关和检查按钮；真实签署是金币操作，确认活跃替换在最新内存状态校验，写入保护与批量使用中禁用，保存失败后禁止重复扣款。新增应用源须接工程生成器。测试RED→GREEN：规范化14条/稳定转换/无效配置；固定钟签署价格、退款源公式、恰好余额/等级不足/未确认不变、严格续费余额边界/级别下降/开关重置/未知保留、双合同顺序与往返/v5原件/futurev7保护。完整Swift/Python、macOS/iOS、签名、工程一致和原README/LICENSE后独立审查、提交推送。产品v0.2.0，正式存档不启动执行迁移/扣款；真实新UI和压力最后。回滚v5程序须先备份整个目录并恢复独立v5原件，不能写回v6。日程队列/执行/等待及停止仍未交付，后续另立规格。

裁决：保留原抽成字段但不新增无源码扣除、保留授权等级续费下降及开关关闭。代价是体验可能与直觉不同，须在界面说明，未来更改须单独更新行为对照及兼容说明。


补充边界裁决：原授权等级反复下降可到0，此时再次按Level=0构造会产生负价格；当前原生报价要求输入等级至少1，0授权过期套餐保留但拒绝续费，提示重新签署，不创建负价格或返款。此处为明确原生保护，非宣称完全等同原漏洞。套餐保存失败在内存保留已执行变更并锁定后续套餐操作，重试/自动保存仅写当前状态，成功后解除，不重放财务命令；该UI路径需最终实机故障注入验收。


验证中发现既有ActivityRenderingTests.testAutonomousClipsFinishAndRestoreWithoutChangingRestState偶发失败：默认随机源下Squat循环退出不是100秒内的必然事件（idleLoopLimit20、B时长3秒），并非套餐改变动画。失败4断言已保留phase5d-animation-red.log诊断；固定该测试随机源1.nextDown确保第21轮退出，验证结束/恢复/打断路径，不改运行规则。无新动画行为，概率本身由已有PetIdleCycles固定输入测试覆盖。

## 最终验证与交接

RED记录：新核心类型/命令缺失、新转换函数缺失；随后9项核心与2项新增Python回归通过。Duration整数约束另经7.5天用例RED→GREEN。162 Swift=98核心+64渲染、17Python、macOS Release/ad-hoc严格签名和iOS Simulator共享模块完整通过，工程重生成与已提交工程字节一致；原README后缀7775字节/LICENSE原字节、文档链接和git diff --check通过。日志为Apple/build/verification/phase5d-*（可再生不入Git）。

Final review: self-review (review-agent thread limit)。新审查代理与既有代理续接均被工具线程限额拒绝，按code-reviewer模板单独自查，没有宣称独立审查完成。核对交易在副本校验后提交、签署/续费不从tick或加载触发、确认后重新校验余额/级别、保存失败锁定/重试不重放、未知合同保留与future v7保护，未发现阻止提交的critical/important问题。自查弱于独立审查，后续独立检查与真实UI/保存失败/DST需补证；尚未创建日程队列，不以套餐能编译作为日程完成。唯一额外验证修订是既有随机退出测试固定随机源，运行规则未改。规格中三项裁决（抽成不增无来源扣除、续费保持授权递减和开关关闭、0级拒绝负价）均保留，不通过补丁掩盖原版与原生的差异。
