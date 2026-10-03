# 阶段2D：内置升级动画 Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL superpowers:executing-plans; Native sequential, one 6.1-sol whole-batch review.

**Goal:** 接入原版萝莉斯LevelUP，有限播放后回基础动作。
**Architecture:** 从固定原版Git恢复82帧原字节，转换3种状态独立单阶段动画；SpriteKit有限播放并沿现有完成回调恢复。AppModel合并一个待播标记，仅空闲且可见/非交互时播放，避免打断进食、拖动和活动收益。
**Tech Stack:** Swift6、SpriteKit、Python原转换器，macOS14/iOS17共享层。
**Spec:** 本文件、PHASE-2C与MainWindow.LevelUP固定1a06c598。

## Global Constraints
不改JSON v9/养成公式，不新增数据MOD/云/联机。保留PNG原字节与逐帧时长，按帧加载/缓存限额保持。原版无Ill升级图，不自动制造或将普通图宣称为Ill图。动画衔接为平台适配，非原Say强制覆盖完全等价。

## Review Focus
- 单阶段只播放一次，完成回到当前基础，不无限循环。
- 投喂、活动、拖动或侧挂期间升级，保留一个待播请求而非抢动作。
- 隐藏/睡眠/恢复存档清除待播，不在未来重新播放过期反馈。
- 当前状态无图跳过并诊断，不回退待机后声称已播升级。
- 资源恢复原字节，资源审计仍要求精确依赖闭包，无遗漏或多打包。

## Task 1：资源、渲染与衔接
Files: Assets/Upstream/VPet/Core/pet/vup/LevelUP; scripts/convert_assets.py; Sources/PetCore/PetState.swift; Sources/PetRendering/PetScene.swift; Apps/macOS/AppModel.swift; scripts/tests; Tests/PetRenderingTests.
Interfaces: PetAction.levelUp; PetScene.playLevelUp(mood:PetMood)->Bool.
- [ ] 写缺少新动作/转换分支的失败测试，覆盖单次完成/缺Ill/活动拒播，恢复源码帧。
- [ ] 转换保留自然排序、125ms逐帧时长，有限播放，AppModel空闲消费待播/生命周期清理。
- [ ] 完整378+新增Swift、26+新增Python、macOS/iOS构建与资源闭包；隔离99经验投喂后有限播放与基础恢复。
- [ ] 独立6.1-sol审查、文档/资源大小更新、提交并推送ipet-dev。

## 恢复与交付
回滚本批代码/资源后重新转换构建，无存档版本改变；无正式数据用于验收。系统睡眠、多屏与两小时压力仍待后续，工具注入不替代物理输入。
