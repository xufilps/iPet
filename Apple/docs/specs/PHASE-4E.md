# 阶段4E：旧库存完整参数预览 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 原样保留旧库存记录并建立类型化只读映射，明确同名参数冲突与原版合并效果，为完整导入提供依据。
**Architecture:** PetLegacyInventoryPreview消费已有LPS文档，提供有序源记录、类型化Item/Food字段及有界诊断。不按当前内置目录覆盖旧参数，不执行插件；本批不发布新运行状态，后续持久化模型与整档导入另立规格。
**Tech Stack:** Swift6/Foundation，LinePutScript1.11.9实际库合成序列化/反序列化夹具。
**Spec:** 本文，固定1a06c598的Item.cs、Food.cs、MainWindow.Save/SavesLoad/ItemsAdd，以及LinePutScript69ea42f7的LPSConvert。

## Global Constraints
- JSON v8、正式用户数据、原LPS字节与原始素材不变；main保持上游镜像，提交仅ipet-dev。
- 保留原README7775字节后缀及LICENSE；压力测试与阶段6不执行。
- 本批只读库存映射不等于旧档可确认导入，不以同名内置商品代替旧商品效果。

## 源码合同
- 原版SavesLoad选择Data中以item开头的键，不限数字后缀；CreateItem仅严格itemtype=Food有内置创建器，其它类型回退Item或依赖插件。
- Item字段：name/itemtype严格名；Image、Price、Desc、Count、Data、CanUse、Star、IsSingle、Visibility标注IgnoreCase。默认Image=null、Name空、ItemType=Item、Price=0、Count=1、Data/Desc空、CanUse/Visibility=true、Star/IsSingle=false。
- Food增加Type枚举Food/Star/Meal/Snack/Drink/Functional/Drug/Gift、Int32 Exp、普通Double Strength/StrengthFood/StrengthDrink/Feeling/Health/Likability、nullable Graph。物品Double不是宠物的1e9固定点。
- Food覆盖ItemType与Star但未重新标注LineAttribute；必须用相同继承DTO及实际SerializeObjectToLine<Line>证明序列化/加载行为，不凭属性名推测。
- ItemsAdd只按Name相等合并Count，保留首件全部参数，忽略IsSingle和后件参数差异。预览保留各源记录并显式列出这种合并造成的差异，不静默应用。
- Food没有覆盖Item.LoadSource；SavesLoad库存路径保留序列化Star/Data。商店目录另调用LoadImageSource/LoadEatTimeSource，从betterbuy/star和buytime更新商店值；单个宠物LPS不足以还原独立设置收藏。8/9月临时数量修补是日期条件，不在导入预览偷偷套用。

## Review Focus
- 同名不同类型/参数的记录不能被当前目录覆盖或无提示合并；Unicode名称按.NET ordinal处理。
- 普通Double、Int32、bool、null标记与枚举编码用实际库夹具；非法/地区相关值明确报告。
- 继承属性是否有LineAttribute及可写setter由实际库证明；大小写语义不能仅凭IgnoreCase标签推断。
- 未知插件类型/字段及item非数字键保留原记录；不得运行代码或访问图片路径。
- 数量溢出、重复字段与诊断上限不可导致崩溃或悄悄丢数据。

## Task 1：原库库存证据
- [x] 扩展legacy_lps_oracle/Program.cs的--items模式，准确复制Item/Food属性继承与标注，覆盖基类/食物、null与字面/null、普通小数、负效果、枚举/布尔及大小写加载。
- [x] 用固定NuGet1.11.9生成legacy-item-fields.json，记录来源、生成命令、SHA256及观察；发现标签和实际加载不同则据库行为修订本文。

## Task 2：只读库存映射
- [x] 先新增PetLegacyInventoryPreviewTests.swift并观察RED，再实现PetLegacyInventoryPreview.swift；有序记录保留sourceLine、所有字段、可表示类型化参数和诊断，未知类型明确unsupported。
- [x] 验证夹具逐字段、同名参数冲突/原合并、默认/重复/非法/边界/未知字段/枚举Star；接入PetLegacySavePreview的只读库存结果，整档仍不支持确认写入。

## Task 3：交付
- [x] 更新审计/差异/行为/交接/README；完整Swift/Python/macOS/iOS共享模块、工程再生及原文许可检查。
- [x] 独立6.1-sol整批审查，必要问题一次RED→GREEN修复；提交推送ipet-dev并核对远程。

## 回滚与下一步
本批只读API和测试可回滚，不改存档格式；原件无需恢复。下一批设计能保存自定义物品参数/元数据的原生库存模型，再映射统计和Data，最后整档预览与双原件备份确认导入。

## Task 1实测裁定
实际库证明派生Food的ItemType与Star继承标注生效，字段IgnoreCase在加载生效；Type枚举值严格大小写，但规范数字0…7可映射已定义项。bool数字0失败；rawInfo=/null代表null，/!null是字面字符串。后续映射须按此证据测试，不以仅命名枚举的简化替代。

最终验证：11项本批回归，全套338 Swift/23 Python/macOS Release/iOS共享编译/严格签名通过。审查加载路径问题一次RED→GREEN修复；夹具loads直接参数化为Minor后续项。原文/许可/工程再生成一致；不代表实机或整档导入完成。
