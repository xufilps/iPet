# 阶段4D：旧LPS完整性校验 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 按原GameSave_v2的两条hash路径核对源档内容，明确宠物子集与整档校验范围，完善只读预览诊断。
**Architecture:** PetLegacyIntegrity使用已解析原始字段及与原库一致的文档序列化，独立计算旧MD5加权与根SHA512/MD5。结果记录状态、路径、范围与预期/计算值；只读预览展示核心诊断，不修改源数据/JSONv8或绕过剩余整档映射。
**Tech Stack:** Swift6/Foundation/CryptoKit；原NuGet1.11.9合成校验样例。
**Spec:** 本文、固定1a06c598 GameSave_v2.load/ToLPS，以及LinePutScript69ea42f7 LpsDocument.ToString、Line.ToString(StringBuilder)、Sub.ToString/GetHashCode。

## 原算法与序列化
1. 若首vpet有hash子字段，移除该字段后，用MD5前8字节little-endian Int64，对name×2、rawInfo×3、rawText×4及每个子字段name×2、解码Info×3做unchecked Int64加总。原代码此路径优先，且只覆盖宠物，不覆盖其它根行/注释。
2. 否则查根hash行并移除该行；ver=2用SHA512前8字节little-endian Int64比较整个剩余文档的库序列化字节。ver缺失或0/1按旧根路径先MD5，失败再尝试SHA512；其它版本报告unsupported，不猜未来格式。-1是原HashCheck=false常见标记，仍按算法比较并说明，不冒称有效。
3. 文档序列化以每行LF开头+name，非空rawInfo附#，再:|，子字段按原顺序拼name与非空#rawInfo及:|，末尾rawText、非空///comment；最后只trim两端LF。保留内存中的原转义，不二次转义/按磁盘原字节直接hash。Line.ToString(StringBuilder)即使空header也附:|，必须用实际库样例核对。
4. 所有根/子名按ordinal；多个vpet、重复同路径hash/版本字段、非规范Int64/版本、未知版本报告unsupported，不静默挑选。原始源字节完整保留。hash匹配只证明原算法结果，不作为签名/来源身份认证。

## 接口与文件
- 扩展PetLegacyLPSDocument canonicalString（只读库序列化）；不提供写档API。
- 新增PetLegacyIntegrity.inspect(document) -> Result，status verified/mismatch/missing/unsupported，path rootSHA512/rootMD5/legacyPetMD5/none，scope document/pet/none，expected/calculated Int64?与中文message。
- PetLegacySavePreview增加integrity，原hash字段/行不再笼统称未实现；mismatch/unsupported标blocking，missing明示未校验，pet-only明示其它行未覆盖。其余库存/统计/Data/hostname继续未迁移。
- 扩展实际NuGetOracle --hashes生成legacy-integrity.json（SHA512v2、MD5old、SHA512oldfallback、petMD5、有注释/转义/空header/延续样例）；增加PetLegacyIntegrityTests.swift。
- 更新审计/差异/行为/交接/README，原LICENSE/原README7775字节后缀及main不变。

## Review Focus / 回归
- 原始文件LF/CRLF/延续与库序列化字节不同，不能直接hash文件；实际canonicalString样例核对。
- little-endian、负Int64、unchecked加权溢出、子Info解码与raw根Info区别；实际原算法夹具核对。
- 旧pet hash优先且范围仅pet；外部Data改动仍可能pet匹配，必须标范围。
- 重复hash/root/版本、无hash、-1标记、非规范/未来版本均不可误报verified。
- 输入变更/转义/注释影响路径不同，JSONv8及正式源档绝不能被重写。

## 步骤
- [x] 实际库生成canonical与四条hash分支合成夹具，来源/哈希记录。
- [x] 测试RED后实现序列化与校验GREEN，预览接入、核心及全套验证。
- [x] 独立6.1-sol整批审查，必要问题单次RED→GREEN修复；工程/许可/README一致，提交推送ipet-dev。

## 后续与回滚
校验不是整档导入；仍需库存参数/统计/Data/套餐/排程及主人持久化，最后预览窗口和双原件备份确认。代码回滚不改变JSONv8，不写原LPS；实机压力/阶段6不执行。
