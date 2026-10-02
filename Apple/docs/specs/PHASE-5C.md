# 阶段5C：原版活动倍率依赖 — 2026-10-02

原ScheduleTask.StartWork要求任务套餐，支持Work.Double(DBL)并按等级降低倍率；winWorkMenu倍率上限min(4000,Level)/(LevelLimit+10)，基础1倍直接原对象。不能将免费无条件排程声称原版迁移，本批先迁移倍率，再后续套餐/抽成/续费和执行器。

源1a06c598 ExtensionFunction.Double/FixOverLoad/Spend/Get/IsOverLoad：倍率>1时需求乘0.5+0.4*n，等级门槛(base+10)*n，收益不是直接乘n，而是始终经过FixOverLoad的有符号幂、Math.Round一位到偶数、等级收益上限和超模兜底。原已规范的时长/奖励比例不随倍率改变；FixOverLoad仍保留时长至少10分钟和奖励0...2修正。实现ActivityDefinition.multiplied(by:)和maximumMultiplier(level:)、PetCatalog.activity(for:)；范围1...400，有效定义校验，非法拒绝。新增命令startMultipliedActivity，保留原startActivity为1倍；按原MainLogic.StartWork同ID再次开始仍停止，倍率变化须先停止再开，失败不改变当前会话。引擎推进、恢复等级检查、完成奖励与活动历史使用有效定义，图层/动画保持原graph。

ActivitySession增加可选multiplier，缺字段=1；大于1写入，会话校验1...400，未知活动仍可保留停止。历史记录保留可选倍率用于查看。JSON升级v5，v1...v4首次写前各自原件备份，未来v6拒绝且不覆盖；导入v1...v5暂停、不补算。活动页每项倍率步进/有效等级与效果展示，选择偏好仅本视图，会话显示锁定倍率，最高值按原级别限制；查询排序沿基础定义。倍率是需求/门槛调整，非承诺等比例收益。配置/状态低于要求拒绝恢复；存档预览显示倍率。

测试先RED：1倍身份、2倍三种活动固定原公式数值、最大倍率边界/无效值、引擎数值与门槛/暂停恢复/完成奖励/同ID停止、v4缺字段升级与独立原件/v5往返/未来版本保护、非法倍率存档拒绝。完整Swift/Python/macOS/iOS、工程一致、原README/LICENSE完整检查及独立审查后提交推送。正式用户存档不执行迁移或恢复，真实新UI和压力最后。回滚程序到v4前退出并备份整个目录，使用独立v4原件恢复，不让旧版覆盖v5。后续套餐/排程仍未实现，规格须另立。


## 审查与修复记录

独立审查确认核心公式、操作顺序、无重复倍率、历史解码、v4主档原字节和future v6保护正确，提出恢复路径未复用最大倍率的边界。原审查标minor，实施重评为需修复：原生开始与继续应对同一有效配置执行同一门槛，JSON导入暂停会话不应绕过本机级别限制。新增娱乐兜底/等级1/暂停2倍会话测试先失败（继续被接受且修改会话），修复恢复复用max倍率校验；不改原倍率或收益公式。已存在不同内容的previous按此前正常轮换策略替换，独立升级原件保留的是被迁移主档/加载源；回滚前仍须复制整个目录，未新增全部历史备份管理。

最终验证：89核心+64渲染=153项Swift、15项Python全部通过，macOS Release/ad-hoc严格签名和iOS Simulator共享模块构建通过。倍率原固定输入2倍参考收益基数为work15.4/study138.4/play52.8；初始测试草稿的预期由源公式独立计算后纠正，再实现规则。额外旧档无load写入与恢复门槛用例均经历RED→GREEN，工程重生成一致、原README尾部7775字节/LICENSE完整及文档链接/git diff --check通过。证据在build/verification/phase5c-{red,green,migration-red,resume-red,final-verify}.log；未启动正式用户版本或执行真实新UI/压力。重评裁决成本是使原生恢复与开始采用相同UI倍率上限；合法当前内置活动不受影响，极端兜底定义仍可停止或降低倍率重新开始。
