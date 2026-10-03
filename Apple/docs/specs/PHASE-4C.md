# 阶段4C：旧档宠物字段与只读预览 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在固定原版依据下生成旧LPS宠物属性候选及完整未支持项清单，禁止把部分宠物映射当作整档导入。
**Architecture:** PetLegacySavePreview接4B解码；保留原始源字节，提供只读petState候选、hostname、原mode和结构诊断。没有保存/恢复API，库存/统计/Data/hash继续分批核对后才开放确认导入；共享核心保持v8，正式数据不读写。
**Tech Stack:** Swift6/Foundation、LinePutScript1.11.9开发夹具。
**Spec:** 本文与LEGACY-SAVE-AUDIT.md；原版1a06c598 GameSave_VPet、GameSave_v2及LinePutScript69ea42f7 LPSConvert。

## 字段与转换合同
原类name/hostname/money/exp及mode显式小写，Level/LevelMax/LikabilityMax普通标量；strength和StoreStrength标ignoreCase，strengthFood/StoreStrengthFood、strengthDrink/StoreStrengthDrink、feeling、health、likability严格区分大小写。前述ToFloat字段规范Int64/1e9；LikabilityMax为普通double，不能缩放。忽略大小写仅用于原类标记的ASCII字段，其他按ordinal首次匹配；同字段出现重复候选明示阻断，不静默合并。
只有一个vpet、空rawInfo的实际桌面类格式生成候选；缺/重复vpet、不支持旧头部格式报告，禁止猜。name必需且符合原生边界，其余缺项按原桌面初始化值（Level1/LevelMax0/LikabilityMax100/modeNomal，其他数值0、hostname空）明示默认。Level/LevelMax按Int32，数字不猜地区；所有无效字段显式阻断候选。经验由原桌面setter推进（负值不降级），Exp的升级先发生，若存在序列化LikabilityMax则后加载覆盖，缺字段则保留经验setter产生的增量，因此最终独立上限保留原语义；超过门槛转换须诊断，原字段值保留。
已有raw属性按2B历史上限验证，不用公开change方法造成再次养成效果。不重置金币、不赠送100、不补离线、不恢复活动/日程；原保存mode的四个规范枚举名称记录，未知/空名称阻断候选，缺字段明示Nomal默认；候选按现有CalMode重算并报告差异。hostname只读保留，尚未写入PetState或UI。petState只代表宠物子集，绝不表示可确认导入。
所有itemN、statistics、hash与其它根行保留在源字节/解析结构，并分组报告未迁移；未知vpet字段也报告。不支持项不丢弃、不误归零或假称兼容；总诊断上限200，额外数量单列。未知库存不能自动拿内置同名参数替代。需要完整字段清单/来源和下一阶段依赖。

## 接口与文件
- 新增 Sources/PetCore/PetLegacySavePreview.swift：init(data:Data) throws，sourceData、document、petState:PetState?、hostName:String?、savedMode:String?、issues:[Issue]、omittedIssueCount。Issue含path/message/severity（warning或blocking）；没有apply/save/readyToImport接口。
- 新增 Tests/PetCoreTests/PetLegacySavePreviewTests.swift；扩展原库Oracle生成独立legacy-pet-fields.json，注解DTO限定源类序列化字段，说明不等于运行Windows程序。
- 更新LEGACY-SAVE-AUDIT/差异/行为/路线/交接，JSONv8/原README/LICENSE不变。

## Review Focus与回归
1. LikabilityMax普通Double被错除1e9；真实DTO序列化fixture检查150.25与固定点money等。
2. 字段顺序/ignoreCase/重复导致错读；明确原属性标记、不同大小写、重复冲突阻断。
3. 经验负值或超门槛以及突破保留属性；原模型场景比对，不重新钳制旧raw值。
4. 缺项默认/无效数值/未知mode/无效name导致误称成功；诊断且不写盘。
5. 有库存/统计/自定义Data但只生成宠物；必须报告其未迁移，源字节完全保留并不提供确认接口。

## 实施步骤
- [x] 固定源码字段审计/DTO实际序列化样例及来源证据。
- [x] 先写字段/完整性/失败/只读回归RED，再实现预览GREEN，完整核心验证。
- [x] 独立6.1-sol整批审查及必要单次RED→GREEN修复；verify/许可/工程一致，提交推送ipet-dev。

## 下一批与恢复
继续库存参数/统计/Data/套餐/排程/hash及主人称呼原生持久化，再形成完整预览UI和原件备份确认合同。本批代码回滚不需降存档，用户原LPS和正式JSON未写；实机压力/阶段6继续不在范围。
