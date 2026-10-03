# 阶段2C：原生升级与突破反馈

> For agentic workers: use superpowers:executing-plans for Native sequential implementation; review the whole batch once after verification.

**Goal:** 补齐运行中的升级/突破提示，不改公式、存档与动画资源。
**Architecture:** PetEngine在drainEvents时合并自上次消费后真实成长变化；独立纯Swift反馈模型计算跨突破的累计升级次数。AppModel保留本次运行最后提示，状态页和非激活工具栏显示；不抢对话、动作或键盘焦点。
**Tech Stack:** Swift6 / SwiftUI / AppKit，macOS14与共享iOS17保持。
**Spec:** 本文件；承接PHASE-2B及桌面GameSave_VPet与MainWindow.LevelUP。

## 源码依据与产品适配
原版固定1a06c598的VPet-Simulator.Windows/MainWindow.cs:2984 LevelUP查询levelup Graph后Say；突破另延迟弹窗。当前仅迁移通知语义，使用原生常驻最近提示而非延迟模态弹窗；专用levelup动画尚未迁移。本地状态增长仍由PetDesktopGrowth负责，不改变阈值或补算离线。

## Global Constraints
不引入多角色/数据MOD/petloader、云存档或联机；不改JSON v9。反馈为会话内状态，不持久化、不授予奖励。加载、导入恢复新引擎建立新基准并清除旧提示，不回放历史成长。

## Review Focus
- 突破后等级下降仍是真实升级，以完整等级路径计算次数。
- 负经验与被拒绝事务不能发出升级提示。
- 连续消费不能重复提示；批量投喂合并增长。
- 已有活动/日程/itemUsed事件必须保留。
- 恢复存档不补发历史提示，不将保存失败隐藏在成长提示里。

## Task 1：成长反馈与原生显示
Files: Sources/PetCore/PetGrowthFeedback.swift, PetEngine.swift, PetActivityRules.swift; Tests/PetCoreTests/PetGrowthFeedbackTests.swift; Apps/macOS/AppModel.swift, ControlsView.swift, PetToolbarWindow.swift.
Interfaces: PetGrowthFeedback.init?(before:PetDesktopGrowth,after:PetDesktopGrowth), message(name:String)->String; PetEvent.growthChanged(PetGrowthFeedback).
- [x] 写并运行失败测试：无变化/负经验、普通与批量升级、单次/多次突破计数、初始加载不发/重复消费不发、事务失败与活动/物品事件共存。
- [x] 实现反馈和消费；界面显示最近升级提示、关闭入口，恢复时清除；工具栏不代替原错误消息。
- [x] 运行核心/渲染/输入测试、macOS Release及严格签名、文档与工程一致性；隔离存档实际跨等级，检查提示和不重复。
- [x] 独立6.1-sol审查，修复重要发现，更新差异/路线/交接，提交并推送ipet-dev。

## 恢复、交付与边界
回滚本批代码重建即可；无存档升级或回退需求，正常退出并保留日常备份。测试仅用隔离目录；真实睡眠、多屏、长期压力及专用升级动画另行验收，不能用通过编译标为完成。

## 完成记录

新增6项核心回归，先观察缺少反馈模型/事件的编译失败，再实现通过；补充有限事务成长后校验失败回滚，以及活动/日程事件共存。完整verify通过，最终378 Swift=277核心+95渲染+6输入、26 Python；macOS Release、iOS共享模块、签名及工程一致性通过。独立6.1-sol审查无阻断，两个测试覆盖建议已补齐。隔离存档99经验使用ab钙奶：Lv1→Lv2，余量3.05/300、好感上限110，状态页显示提示；关闭后下一采样不重现。工具栏接入已构建验证，独立面板新提示视觉未另验。测试实例正常退出，日常实例恢复；正式档未用于测试。原始日志在Apple/build/verification/growth-feedback*，隔离档在growth-feedback/save。
