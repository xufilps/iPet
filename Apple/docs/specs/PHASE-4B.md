# 阶段4B：Windows LPS 旧档解码层 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 建立有原版固定库样例依据、保留顺序和重复字段、正确读取存档浮点编码的纯Swift解码层，作为完整一次性导入前置。
**Architecture:** PetLegacyLPS只解析结构与原始字段，不改PetState、不写盘、不执行插件；解析结果保留原顺序、重复项及原始Info。后续字段映射必须显示未支持项并保留源字节，不把解析成功当完整导入成功。
**Tech Stack:** Swift6/Foundation；测试夹具由LinePutScript1.11.9生成，辅助.NET工具只在构建目录运行。
**Spec:** 本文及[旧档字段审计](../LEGACY-SAVE-AUDIT.md)。

## 原版依据及合同
固定LinePutScript标签v1.11.9，提交69ea42f7f213be2669879705035a77a1804c457a。FInt64(double)把value×1e9截断成Int64，ToStoreString写整数，Parse先尝试Int64再尝试double，ToDouble为原整数/1e9（NaN哨兵特殊）。保存的规范整数字符串必须按此解码，Level等普通整数不缩放。避免猜地区格式：非规范数值明确拒绝，后续预览报告，不把普通十进制误当存档规范。
LpsDocument.Load先移除CR，再把冒号+换行+竖线替换/n，把冒号+换行+冒号移除，最后按非空LF分行。Line.Load先分第一个///注释，再按:|切分，首段为name#info，末段为text，中间为Sub，Sub按第一个#分name/info。名称按原库ordinal字符序列比较，不采用Swift规范等价；名称大小写不折叠；字段保留重复项，first lookup按原Find规则。TextDeReplace按固定顺序stop/equ/tab/n/r/id/com/!/|解码，不能提前去转义再分结构。
限输入8MiB UTF8（可有BOM）、10000行、每行2000Sub；无效UTF8或超限显式失败。未知字段与注释保留，空行遵循原源；有歧义内容不静默字典覆盖。浮点Int64哨兵/非规范/越界拒绝，原库正负Infinity实现差异须用实际样例确认并在文档报告。

## 文件与接口
- 新增 Sources/PetCore/PetLegacyLPS.swift：PetLegacyLPSDocument.parse(Data) throws；lines数组、Line(name,rawInfo,rawText,comment,fields)、Field(name,rawInfo)，info/text按需解码；firstField(named:)严格匹配；storedFloat(String) throws -> Double规范固定点解码。
- 新增 Tests/PetCoreTests/PetLegacyLPSTests.swift；Fixtures/legacy-lps-v1.11.9.json及SOURCE文档，Tests脚本路径定位沿现有夹具方式。
- 新增 scripts/legacy_lps_oracle/Program.cs与csproj，引用NuGet1.11.9，固定合成数据生成夹具；不把上游库源码打包进应用。
- 更新审计/行为/差异/交接，原README后缀及LICENSE不变，PetState v8不变。

## Review Focus
1. 普通数字与固定点混淆导致钱包/经验放大十亿倍；规范数值测试必须真实库生成。
2. 转义顺序把文本里的分隔符变成结构；literal /n、:|、#、逗号、竖线样例。
3. 重复或大小写字段静默覆盖；保留全部、first lookup严格比较。
4. CRLF/多行延续/注释与空末文本切分；原库解析结果逐项核对。
5. 畸形Unicode、超大文件/行/sub、Int64溢出与哨兵；拒绝不陷阱，源文件不写入。

## 执行步骤
- [x] 任务1：运行固定1.11.9库，生成结构/数值夹具与原始输入、记录来源和输出哈希；核对源码与实际结果。
- [x] 任务2：先写Swift夹具与边界测试，观察缺API失败，实现有界纯解码，观察GREEN；运行全部核心测试。
- [x] 任务3：独立6.1-sol整批审查，必要问题单次RED→GREEN修复；完整verify、工程一致、许可/README/文档链接；提交推送ipet-dev。

## 交付边界、风险与恢复
这只是完整旧档导入的第一批，不新增导入菜单，不修改正式档。下一批依次映射宠物名/主人称呼、原等级及属性、库存参数、统计与Data/套餐/排程，明确hash及溢出修复，最后预览确认/双原件备份/原子发布。代码回滚不改变v8；删除可再生构建目录不影响源LPS。真实实机/压力及阶段6不在本批。
