# 阶段2A：Windows桌面版等级模型纠偏 — 2026-10-03

## 发现与目标
旧LPS导入前复核确认：MainWindow.SavesLoad将GameSave_v2.GameSave（GameSave_VPet）赋给Core.Save；不是Core/Handle/GameSave。当前PetState沿用Core累计经验/固定100上限。先还原桌面等级模型，再接存档迁移与LPS导入，禁止为了快速导入截掉超100属性或将剩余经验当累计经验。
源码基线1a06c598：Windows.Interface/GameSave_VPet.cs，Windows.Interface/GameSave_v2.cs及Windows/MainWindow.cs:915–992。纯Swift实现，不依赖平台。

## 原公式与边界
GameSave_VPet.Exp是当前等级剩余经验；LevelUpNeed=200*Level-100；达到门槛（含相等）扣门槛、好感上限加10、Level加1。Level严格大于1000+100*LevelMax时，LevelMax加1，Level改为100*LevelMax，继续升级。负经验不降低Level。每次赋值仅发一次汇总升级事件，包含前后等级/突破与本次是否突破。
StrengthMax=100+Int(pow(Level*(1+LevelMax),0.75)*4)，FeelingMax=100+Int(pow(...)*2)，正数截断。好感上限独立持久化，不能每次从等级强行重算。新角色等级1、突破0、好感上限100，桌面版初始金币100（当前iPet1000为待纠偏差异）。CalMode原桌面源码Feeling/FeelingMax>=80，通常不可达到，不能擅自换成>=0.8；原Core采用Feeling>=80。高兴/不佳按Feeling/FeelingMax及好感阈值判断，其余健康边界保持原顺序。

## 实施顺序与接口
1. 本批交付PetDesktopGrowth纯模型（Codable/Equatable/Sendable）：等级、突破次数、剩余经验、好感上限；验证和事务性setExperience/addExperience；派生体力/心情上限与状态判断；总升级数和原一次汇总事件。精确批量求和与二分代替逐等级大循环，拒绝非有限/过大输入，不将正常大额经验补给变卡顿。通过逐步C#公式参考循环作固定场景对比。
2. 下一批接入PetState/引擎和原生面板，升级JSON存档版本；保持v1–v7原件，明确累计经验到新剩余经验的迁移，不静默覆盖未来版本。审计抚摸/活动/投喂/统计/文本的全部100常量与经验写入，不能只改level计算。
3. 再实现一次性LPS预览/报告/导入，核对LinePutScript浮点编码与转义、vpet/库存/统计/套餐/排程，先备份当前JSON和来源原字节，不修改原LPS；未知内容报告，不冒称完整插件/MOD兼容。

本批模型接入前不改变运行时养成和v7；文档必须区分“模型已实现”和“已用于应用”。包含源头审计文档和待映射表，不把工具或目录当兼容完成。

## 测试、限制与恢复
覆盖等级1/1000及连续突破、相等/差一、负经验不掉级、大额与参考循环一致、重复确定性、独立好感上限、非有限/界限/溢出原值保持、Codable验证、等级派生状态边界。模型范围LevelMax0...10000、经验绝对值≤1e12、好感上限≤1e12，越界拒绝而非截断；可支持的范围不等同原C#无限整数/溢出行为。
完整Swift/Python回归、macOS与iOS共享模块构建、严格签名、工程重生成一致和原README/许可完整性。先提交规格，再实现和独立6.1-sol审查，推送ipet-dev；main不改。正式存档/用户LPS不读写，模型阶段回滚提交即可；之后运行时迁移另立规格/备份与恢复规则。实机与压力继续最后。
