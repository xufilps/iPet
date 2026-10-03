# 阶段3AK：随宠工具栏分组活动菜单 Implementation Plan

> For agentic workers: use superpowers:executing-plans, Native sequential, one independent6.1-sol reviewer.

**Goal:** 不打开大面板即可选择内置工作/学习/娱乐，保留完整活动面板入口。
**Architecture:** 原Toolbar.LoadWork按类别生成子菜单，在原生工具栏“活动”单层菜单中按Section分组适配；共享纯Swift菜单项投影给出状态/等级门槛与当前活动标记。操作仍走AppModel.perform与PetEngine事务，不直接修改状态或结算。
**Tech Stack:** Swift6 SwiftUI/AppKit，macOS14/iOS17保持。
**Spec:** 本文件；原基线1a06c598 ToolBar.xaml.cs.LoadWork/StartWork与现有ActivityView。

## Global Constraints
使用13内置活动，默认1倍；倍率/套餐/收藏继续完整面板设置；不改养成公式/JSON9/资源/快捷按键权限。菜单不启动额外实例、不执行插件。无可用类别不显示空类别分组。禁用门槛包括等级、生病、养成关闭、保存只读/失败和批量使用；执行时重新校验，不能靠菜单快照绕过。

## Review Focus
活动ID保持目录顺序与类别；当前相同活动入口语义明确为停止；菜单禁用与底层保护一致；失败消息继续可見且不增加财务副作用；弹出菜单不抢键盘主窗口、不改变工具栏启用偏好。

## Task 1：分组菜单与安全入口
Files: Sources/PetCore/PetActivityMenu.swift; Tests/PetCoreTests/PetActivityMenuTests.swift; Apps/macOS/PetToolbarWindow.swift, AppModel.swift.
Interfaces: PetActivityMenuAccess.allowsSelection（保存/养成/生命周期门槛）, PetActivityMenuItem(Identifiable/Sendable), PetActivityMenu.items(catalog:state:enabled:)->[PetActivityMenuItem].
- [x] 失败测试目录顺序/分类、等级/疾病/关闭/不可写禁用、当前活动停止标记。
- [x] 实现纯投影与SwiftUI Menu类别分组/完整管理入口，ToolbarAction.startActivity(String)复用事务；点击时再次检查busy/visibility/suspended。
- [x] 全套Swift/Python/macOS/iOS与工程检查。
- [x] 隔离单层菜单可见、低等级禁用、文案启动停止与焦点：用户复核“全部正常”；完整面板入口保持既有路径。
- [x] 独立6.1-sol审查，记录实机失败与单层分组适配。
- [x] 完成交接/差异/路线更新；随本批提交并推送ipet-dev。

## 回滚与边界
回滚代码重建即可，不涉及保存版本；测试用隔离档。工具栏自动隐藏、完整WorkTimer和新菜单真实鼠标焦点仍独立验收，不能因新增菜单就称工具栏全部还原。

## 完成与验收边界

3项新核心测试先因缺模型失败，再通过。全套384 Swift=280核心+98渲染+6输入、27 Python、macOS/iOS共享模块构建、签名与工程/资源闭包通过；独立6.1-sol审查无可修复发现。选择器使用默认1倍，相同ID停止既有会话，倍率和套餐转完整面板。隔离存档toolbar-menu/save，实际设置启用工具栏并关闭大面板；独立工具栏菜单的显示、点击及物理焦点等待用户配合，工具无法直接捕获该面板，不将编译当实机验收。原始日志Apple/build/verification/toolbar-menu*，正式档不用于测试。

## 实机发现与适配

用户复核RED：外层活动菜单能打开，但工作/学习/娱乐二级菜单无法展开；未证实具体SwiftUI/AppKit内部原因，不能写成系统通用缺陷。工具栏非激活窗口且每250ms更新，采用单层Section分组替代嵌套Menu，13项直接可点击、权限与执行门槛保持。Ruling：交付分组单层菜单而非原版层级完全等价，减少展开步骤并避开已复现路径；自动检查后用户复核仍是必要视觉/点击证据。原先实机门槛仍待通过，不以构建掩盖RED。

修正版GREEN（2026-10-03）：重新构建后以同一隔离目录启动，用户对单层分组、文案启动/停止、高等级项灰色与键盘焦点回答“全部正常”。完整自动验证再次通过384 Swift/27 Python、macOS Release、iOS共享模块、严格签名和资源闭包；代码审查无修复发现，已修正规格中过早勾选的实机/推送状态。睡眠、多屏与长期压力仍待最后验收。

隔离验收结束时pet.json与pet.previous.json均为版本9、activity为空，完成启动/停止后的保存检查；测试进程正常退出并恢复日常版，正式存档未用于上述活动操作。
