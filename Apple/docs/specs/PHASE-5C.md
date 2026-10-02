# 阶段5C：原版活动倍率依赖 — 2026-10-02

原ScheduleTask.StartWork要求任务套餐，支持Work.Double(DBL)并按等级降低倍率；winWorkMenu倍率上限min(4000,Level)/(LevelLimit+10)，基础1倍直接原对象。不能将免费无条件排程声称原版迁移，本批先迁移倍率，再后续套餐/抽成/续费和执行器。

源1a06c598 ExtensionFunction.Double/FixOverLoad/Spend/Get/IsOverLoad：倍率>1时需求乘0.5+0.4*n，等级门槛(base+10)*n，收益不是直接乘n，而是始终经过FixOverLoad的有符号幂、Math.Round一位到偶数、等级收益上限和超模兜底。时长/奖励比例不随倍率改变。实现ActivityDefinition.multiplied(by:)和maximumMultiplier(level:)、PetCatalog.activity(for:)；范围1...400，有效定义校验，非法拒绝。新增命令startMultipliedActivity，保留原startActivity为1倍；按原MainLogic.StartWork同ID再次开始仍停止，倍率变化须先停止再开，失败不改变当前会话。引擎推进、恢复等级检查、完成奖励与活动历史使用有效定义，图层/动画保持原graph。

ActivitySession增加可选multiplier，缺字段=1；大于1写入，会话校验1...400，未知活动仍可保留停止。历史记录保留可选倍率用于查看。JSON升级v5，v1...v4首次写前各自原件备份，未来v6拒绝且不覆盖；导入v1...v5暂停、不补算。活动页每项倍率步进/有效等级与效果展示，选择偏好仅本视图，会话显示锁定倍率，最高值按原级别限制；查询排序沿基础定义。倍率是需求/门槛调整，非承诺等比例收益。配置/状态低于要求拒绝恢复；存档预览显示倍率。

测试先RED：1倍身份、2倍三种活动固定原公式数值、最大倍率边界/无效值、引擎数值与门槛/暂停恢复/完成奖励/同ID停止、v4缺字段升级与独立原件/v5往返/未来版本保护、非法倍率存档拒绝。完整Swift/Python/macOS/iOS、工程一致、原README/LICENSE完整检查及独立审查后提交推送。正式用户存档不执行迁移或恢复，真实新UI和压力最后。回滚程序到v4前退出并备份整个目录，使用独立v4原件恢复，不让旧版覆盖v5。后续套餐/排程仍未实现，规格须另立。
