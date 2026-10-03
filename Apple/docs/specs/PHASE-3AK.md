# 阶段3AK：随宠工具栏分组活动菜单 Implementation Plan

> For agentic workers: use superpowers:executing-plans, Native sequential, one independent6.1-sol reviewer.

**Goal:** 不打开大面板即可选择内置工作/学习/娱乐，保留完整活动面板入口。
**Architecture:** 原Toolbar.LoadWork按类别生成子菜单，在原生工具栏“活动”菜单中重建；共享纯Swift菜单项投影给出状态/等级门槛与当前活动标记。操作仍走AppModel.perform与PetEngine事务，不直接修改状态或结算。
**Tech Stack:** Swift6 SwiftUI/AppKit，macOS14/iOS17保持。
**Spec:** 本文件；原基线1a06c598 ToolBar.xaml.cs.LoadWork/StartWork与现有ActivityView。

## Global Constraints
使用13内置活动，默认1倍；倍率/套餐/收藏继续完整面板设置；不改养成公式/JSON9/资源/快捷按键权限。菜单不启动额外实例、不执行插件。无可用类别不显示空子菜单。禁用门槛包括等级、生病、养成关闭、保存只读/失败和批量使用；执行时重新校验，不能靠菜单快照绕过。

## Review Focus
活动ID保持目录顺序与类别；当前相同活动入口语义明确为停止；菜单禁用与底层保护一致；失败消息继续可見且不增加财务副作用；弹出菜单不抢键盘主窗口、不改变工具栏启用偏好。

## Task 1：分组菜单与安全入口
Files: Sources/PetCore/PetActivityMenu.swift; Tests/PetCoreTests/PetActivityMenuTests.swift; Apps/macOS/PetToolbarWindow.swift, AppModel.swift.
Interfaces: PetActivityMenuItem(Identifiable/Sendable), PetActivityMenu.items(catalog:state:enabled:)->[PetActivityMenuItem].
- [ ] 失败测试目录顺序/分类、等级/疾病/关闭/不可写禁用、当前活动停止标记。
- [ ] 实现纯投影与SwiftUI Menu类别子菜单/完整管理入口，ToolbarAction.startActivity(String)复用事务；点击时再次检查busy/visibility/suspended。
- [ ] 全套Swift/Python/macOS/iOS与工程检查，隔离菜单可见/低等级禁用/启动停止/面板入口实测。
- [ ] 独立6.1-sol审查、交接/差异/路线更新，提交推送ipet-dev。

## 回滚与边界
回滚代码重建即可，不涉及保存版本；测试用隔离档。工具栏自动隐藏、完整WorkTimer和新菜单真实鼠标焦点仍独立验收，不能因新增菜单就称工具栏全部还原。
