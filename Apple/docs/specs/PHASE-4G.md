# 阶段4G：旧统计类型与只读映射 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 按原源码的统计用途解释旧字段，保留原值与类型差异，不把所有统计当Double或宠物固定点导入。
**Architecture:** 基于实际SetObject库生成统计存储/加载证据，建立已核对字段类型注册表。PetLegacyStatisticsPreview保留每个原字段并提供Int32/Int64/Double只读值，未知或地区相关/非规范内容明确阻断；独立列出可供原生计数器承载的数值子集及不兼容原因，不发布PetState或确认写入。
**Tech Stack:** Swift6/Foundation；固定LinePutScript1.11.9 NuGet和1a06c598 Statistics/MainWindow/MainWindow_Function/MainWindow.xaml.cs。
**Spec:** 本文及上述固定来源；原库SetObject结构与ConverterSetObjectToStoreString。

## Global Constraints
JSON仍v9，正式用户数据/原LPS字节不变；不运行插件、不取代未知数据、不补离线；原README7775字节/许可/main不变，实机压力/阶段6留后。

## 原存储及读取合同
Statistics.Data为SortedDictionary<string,SetObject?>；AddRange把ISub.name及原info添加，重复键抛错，不按首次字段丢后者。ToSubs跳过null值，new Sub(key,SetObject)，保留原存储转换。统计值没有磁盘类型标签。
SetObject存储int/long普通整数、double普通地区小数、FInt64为1e9固定点、DateTime/TimeSpan为ticks、bool为True/False、string原文字。GetInteger可先Int32、再Int64转Int32（可能溢出）、再Double截断，日期/TimeSpan也有回退；GetDouble解析失败返回0。这些宽松回退不能作为迁移中丢原值的理由。
本批按规范整数/Invariant有限普通小数解释已核对内置键；非规范、地区相关、非法/溢出或未知字段保留原值并报告，不悄悄复现归零/截断/溢出。DateTime、bool、固定点只在实际库样例证明编码，不凭数字形态认定内置统计类型。

## 已核对类型来源
| 类别 | 字段 | 源码 |
| --- | --- | --- |
| Int32 | stat_level；stat_ill_nomoney/stat_level_g_money/stat_0_feel/stat_0_f_sd/stat_0_all/stat_0_strengthfood/stat_0_strengthdrink/stat_0_sd_sf/stat_100_all | MainWindow StatisticsCalHandle 862…911，数字1标记不是bool |
| Int64 | stat_total_time/stat_work_time/stat_study_time/stat_sleep_time | 同入口gi64写入；旧界面/修复路径仍有gint读取/写入，不声称溢出完全兼容 |
| Double | stat_money/stat_likability | 同入口从IGameSave普通Double赋SetObject，不是宠物ToFloat |
| Int32 | stat_buytimes/buy_{原物品名}、stat_say_exp_p/d/stat_say_like_p/d/stat_say_money_p/d/stat_menu_pop/stat_open_times | MainWindow TakeItem/对话/菜单/启动 |
| Double | stat_betterbuy/stat_bb_food/drink/drug/snack/functional/meal/gift/stat_bb_drug_exp/stat_bb_gift_like | MainWindow TakeItem 778…804；旧重置入口有gint兼容写入，原值整数仍可普通Double读取 |
| Int32 | stat_single_profit_money/exp/stat_touch_body/head/stat_say_times/stat_move_length | MainWindow.xaml.cs 767…792，移动写gint但界面读gi64 |
| Int32 | eval_last_active_day/eval_active_days/eval_active_streak/eval_longest_active_streak、eval_work/study_started/completed、eval_work/study_project_{EscapeDataString名称} | MainWindow_Function RegisterEvaluationActiveDay/WorkStart/WorkEnd |
| Int64 | eval_longest_session_seconds/eval_recent_7_days_seconds/eval_recent_30_days_seconds、eval_day_yyyyMMdd/eval_month_yyyyMM | MainWindow_Function EvaluationStatisticsCalHandle |
| Double | eval_work_total_money/eval_study_total_exp/eval_work_completion_rate/eval_study_completion_rate | 同文件WorkEnd/UpdateEvaluationCompletionRate |
未查到原内置statistics使用gdat/gflt写入；接口有能力不代表这些值全属日期/固定点。其它旧统计键、插件键和类型冲突另列未知，不能仅匹配stat_前缀。

## Task1：实际库证据
- [x] 扩展Oracle --statistics，模拟Statistics.ToSubs/AddRange，生成普通数值/大Int64、DateTime ticks、FInt64、bool/转义文字及宽松读取差异样例；保留严格原culture。
- [x] 验证序列化确定性、字段普通/固定点差异及Int64精确原值，记录来源/SHA256和地区风险。

## Task2：只读映射
- [ ] RED后实现PetLegacyStatisticsPreview及Tests，按上表registry精准键/动态模式，Int64保留精确整数。大小写不归一；源字段/未知/重复/非法值保留，诊断最多200条。
- [ ] 唯一statistics根才提供映射；未知/重复不能当完整成功。原生计数器子集仅key≤400、abs≤1e12的精确承载数值；buy_原名称不得擅自换成native ID，映射依赖库存ID选择另处理。
- [ ] PetLegacySavePreview增加statistics只读结果，保持整档仍不可确认导入；原日期/文本/插件内容保留并解释，非规范不猜。

## Task3：验证与交付
- [ ] 全套Swift/Python/macOS/iOS共享编译/签名、工程再生成/原文许可/链接；独立6.1-sol整批审查、必要一次RED→GREEN修复，文档与交接更新，提交推送ipet-dev。

## Review Focus
同文本多种读取/文化差异；stat_money普通Double与宠物固定点；Int64→Double精度；动态名称键未映射ID；重复/文化相关字典名称不静默丢数据。未知含日期/文本原件必须保留，不把只读子集当整档兼容。

## 回滚与后续
本批无保存/发布状态变更，回滚代码无需恢复档案。后续继续Data中的buytime/套餐/排程/主人及扩展内容映射，建立完整导入规格、双原件备份和确认窗口；原生历史不猜测，不用读取一次statistics就宣称原统计完整迁移。

Task1实测：统计无类型标签，DateTime存ticks，FInt64固定点；大Int64转Double丢1，整数读取截断/溢出，非法读Double归0。fr-FR写1,25在Invariant读为125，不能把当前culture回退当无损迁移。Statistics.AddRange接ISub.info原文字，GetString不解码转义；未知文本需保留rawInfo。四种Oracle模式重新生成逐字节一致。Task2尚未实现，JSON/运行时不变。
